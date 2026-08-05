//
//  Repository.swift
//  Sycamore
//
//  The seam. `SycamoreRepository` is every read and write the twelve screens need,
//  expressed as `async throws` so a Supabase-backed implementation can drop in behind
//  it without a single view changing. `InMemoryRepository` is the offline stand-in,
//  seeded from `SampleData`.
//
//  Two conventions worth knowing before you add a method:
//
//  1. Every mutation that touches a camp returns the whole camp back. A backend will
//     re-select the graph after a write anyway, and it means callers never have to
//     patch local state by hand.
//  2. Nothing here knows about SwiftUI, navigation, or the current selection. That all
//     lives in `AppStore`.
//

import Foundation

// MARK: - Sign-in

/// What the server tells us after it posts a code. `resendAfter` is the 0:42 countdown.
struct SignInChallenge: Hashable, Sendable {
    var email: String
    var codeLength: Int = 6
    var resendAfter: Int = 42
    var sentAt: Date = .now
}

enum SycamoreError: LocalizedError, Equatable {
    case invalidEmail
    case invalidCode
    case unknownAccount
    case unknownCamp
    case unknownVenue
    case unknownGroup
    case unknownPlayer
    case unknownStaff
    case unknownInviteCode
    case campNameRequired
    case notPermitted

    var errorDescription: String? {
        switch self {
        case .invalidEmail: "That doesn't look like an email address."
        case .invalidCode: "That code didn't work. Try again."
        case .unknownAccount: "We couldn't find that account."
        case .unknownCamp: "We couldn't find that camp."
        case .unknownVenue: "We couldn't find that venue."
        case .unknownGroup: "We couldn't find that court."
        case .unknownPlayer: "We couldn't find that kid."
        case .unknownStaff: "We couldn't find that person."
        case .unknownInviteCode: "No camp uses that code."
        case .campNameRequired: "Give the camp a name first."
        case .notPermitted: "Only an admin can do that."
        }
    }
}

// MARK: - Protocol

/// Inherits `SectionEightData` (in `SectionEightRepository.swift`) so a call site only ever
/// sees one repository. The split is about who edits which file, not about two capabilities.
protocol SycamoreRepository: SectionEightData {

    // MARK: Identity

    /// Screen 1. Posts a one-time code and returns the resend window.
    func requestSignInCode(email: String) async throws -> SignInChallenge
    /// Screen 2. Trades the six digits for an account.
    func verifySignInCode(_ code: String, email: String) async throws -> Account
    /// Screen 1's "Continue with Apple". The token is whatever `ASAuthorization` hands
    /// back; the in-memory build ignores it.
    func signInWithApple(identityToken: String) async throws -> Account
    func signOut() async throws

    func account(id: Account.ID) async throws -> Account
    func updateAccount(_ account: Account) async throws -> Account
    func deleteAccount(id: Account.ID) async throws

    // MARK: Camps

    /// Screen 3's "Your camps".
    func memberships(forAccount accountID: Account.ID) async throws -> [Membership]
    /// The whole camp graph in one shot.
    func camp(id: Camp.ID) async throws -> Camp
    /// Screen 3's code field. Idempotent — joining twice returns the same membership.
    func joinCamp(inviteCode: String, accountID: Account.ID) async throws -> Membership
    /// Screen 4. The creator becomes the camp's first admin.
    func createCamp(_ draft: CampDraft, accountID: Account.ID) async throws -> Membership

    // MARK: The day

    /// Screen 5's swipe action and the player sheet's "Mark away today".
    func setAttendance(
        playerID: Player.ID, day: Weekday, present: Bool, campID: Camp.ID
    ) async throws -> Camp
    /// Screen 10. Pass `nil` to cancel a pick-up that was already set.
    func setEarlyPickup(
        playerID: Player.ID, day: Weekday, leavesAt: TimeOfDay?, campID: Camp.ID
    ) async throws -> Camp

    // MARK: Order

    /// A drag inside one coach's card on screen 5.
    func reorderGroup(
        _ groupID: Group.ID, playerIDs: [Player.ID], campID: Camp.ID
    ) async throws -> Camp
    /// A drag on screen 6. Sections arrive top to bottom, so a kid dropped across a
    /// venue rule simply appears in the next section and changes venue.
    func reorderCamp(_ assignments: [RankAssignment], campID: Camp.ID) async throws -> Camp
    /// The player sheet's "Move up a court", and any explicit venue change.
    func movePlayer(
        _ playerID: Player.ID, toVenue venueID: Venue.ID, group groupID: Group.ID?, campID: Camp.ID
    ) async throws -> Camp
    /// Setup's "Partition the camp" — fills each venue by rank, inside its limits.
    func partitionCamp(_ campID: Camp.ID) async throws -> Camp
    /// Screen 6's "Even out" — levels the courts inside every venue.
    func evenOut(_ campID: Camp.ID) async throws -> Camp

    // MARK: Shape

    /// Screen 11. Name, subtitle, icon and all four limits in one write.
    func updateVenue(_ venue: Venue, campID: Camp.ID) async throws -> Camp
    /// Setup's "Add" beside the VENUES header.
    func addVenue(campID: Camp.ID) async throws -> Camp
    /// Screen 12's role chips.
    func updateStaffRole(_ staffID: StaffMember.ID, role: Role, campID: Camp.ID) async throws -> Camp
    /// Screen 12's court chips. `nil` means "No court".
    func assignStaff(
        _ staffID: StaffMember.ID, toGroup groupID: Group.ID?, campID: Camp.ID
    ) async throws -> Camp
    /// Screen 12's "Remove from camp".
    func removeStaff(_ staffID: StaffMember.ID, campID: Camp.ID) async throws -> Camp
}

// MARK: - In-memory implementation

/// An actor so the whole thing is `Sendable` without ceremony, and so the shape of the
/// call sites already matches a network client.
actor InMemoryRepository: SycamoreRepository {

    private var accounts: [Account.ID: Account]
    private var membershipRecords: [Membership]
    private var camps: [Camp.ID: Camp]
    /// The last code we "sent", per email. The offline build accepts any six digits.
    private var pendingChallenges: [String: SignInChallenge] = [:]

    // Section 8's three new shapes. They sit beside the camp graph rather than inside it
    // because `Camp` predates them, and folding courts, blocks and inbox rows into it would
    // mean every existing screen re-decoding three things it does not use. Not `private` —
    // `SectionEightRepository.swift` implements against them from an extension, and an
    // extension cannot reach a private stored property.
    var sectionEightCourts: [CourtCard] = []
    var sectionEightBlocks: [ScheduleBlock] = []
    var sectionEightInbox: [InboxItem] = []

    /// Empty by default: a fresh install has no account, no memberships and no camps until
    /// someone signs in and creates or joins one.
    ///
    /// These used to default to `SampleData`, which meant the shipped app opened already
    /// populated with a fictional camp. The fixtures are still there and still used — every
    /// `#Preview` and the `AppStore.preview` family pass them in explicitly — but they are no
    /// longer what a real person sees on first launch.
    init(
        accounts: [Account] = [],
        memberships: [Membership] = [],
        camps: [Camp] = []
    ) {
        self.accounts = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0) })
        self.membershipRecords = memberships
        self.camps = Dictionary(uniqueKeysWithValues: camps.map { ($0.id, $0) })
    }

    // MARK: Identity

    func requestSignInCode(email: String) async throws -> SignInChallenge {
        let address = EmailAddress.normalised(email)
        guard EmailAddress.isValid(address) else { throw SycamoreError.invalidEmail }
        let challenge = SignInChallenge(email: address)
        pendingChallenges[address] = challenge
        return challenge
    }

    func verifySignInCode(_ code: String, email: String) async throws -> Account {
        let digits = code.filter(\.isNumber)
        guard digits.count == 6 else { throw SycamoreError.invalidCode }
        return try signIn(email: email)
    }

    func signInWithApple(identityToken: String) async throws -> Account {
        // A real client would exchange the token for the address behind it. Offline there is
        // nothing to exchange, so we stand in a relay address of the shape Apple actually
        // hands out; `signIn` creates the person if this is their first time.
        try signIn(email: "apple.user@privaterelay.appleid.com")
    }

    func signOut() async throws {
        pendingChallenges.removeAll()
    }

    func account(id: Account.ID) async throws -> Account {
        guard let account = accounts[id] else { throw SycamoreError.unknownAccount }
        return account
    }

    func updateAccount(_ account: Account) async throws -> Account {
        guard accounts[account.id] != nil else { throw SycamoreError.unknownAccount }
        accounts[account.id] = account
        return account
    }

    func deleteAccount(id: Account.ID) async throws {
        guard accounts.removeValue(forKey: id) != nil else { throw SycamoreError.unknownAccount }
        membershipRecords.removeAll { $0.accountID == id }
    }

    /// Offline, an unknown address simply becomes a new person rather than an error, so
    /// the sign-in screens can be driven with anything.
    private func signIn(email: String) throws -> Account {
        let address = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let existing = accounts.values.first(where: { $0.email.lowercased() == address }) {
            return existing
        }
        let account = Account(
            email: address,
            displayName: address.split(separator: "@").first.map(String.init)?.capitalized ?? "You",
            emergencyPhone: nil
        )
        accounts[account.id] = account
        return account
    }

    // MARK: Camps

    func memberships(forAccount accountID: Account.ID) async throws -> [Membership] {
        membershipRecords.filter { $0.accountID == accountID }
    }

    func camp(id: Camp.ID) async throws -> Camp {
        guard let camp = camps[id] else { throw SycamoreError.unknownCamp }
        return camp
    }

    func joinCamp(inviteCode: String, accountID: Account.ID) async throws -> Membership {
        let needle = Self.normalise(inviteCode)
        guard let camp = camps.values.first(where: { Self.normalise($0.inviteCode) == needle }) else {
            throw SycamoreError.unknownInviteCode
        }
        if let existing = membershipRecords.first(where: { $0.accountID == accountID && $0.campID == camp.id }) {
            return existing
        }
        // A code hands out the lowest useful permission; an admin promotes from Setup.
        let membership = Membership(
            accountID: accountID,
            campID: camp.id,
            role: .worker,
            todayAssignment: nil,
            campName: camp.name,
            campIcon: camp.icon,
            campTint: camp.tint,
            campSummary: camp.summaryLine
        )
        membershipRecords.append(membership)

        var updated = camp
        let account = accounts[accountID]
        updated.staff.append(
            StaffMember(
                accountID: accountID,
                name: account?.displayName ?? "New coach",
                role: .worker,
                phone: account?.emergencyPhone,
                isRoaming: false,
                assignment: nil
            )
        )
        updated.reindex()
        camps[camp.id] = updated
        return membership
    }

    func createCamp(_ draft: CampDraft, accountID: Account.ID) async throws -> Membership {
        guard draft.isValid else { throw SycamoreError.campNameRequired }
        var camp = Camp.make(from: draft, inviteCode: Camp.inviteCode(for: draft.name))
        let account = accounts[accountID]
        camp.staff.append(
            StaffMember(
                accountID: accountID,
                name: account?.displayName ?? "You",
                role: .admin,
                phone: account?.emergencyPhone,
                isRoaming: false,
                assignment: nil
            )
        )
        camp.reindex()
        camps[camp.id] = camp

        let membership = Membership(
            accountID: accountID,
            campID: camp.id,
            role: .admin,
            todayAssignment: nil,
            campName: camp.name,
            campIcon: camp.icon,
            campTint: camp.tint,
            campSummary: camp.summaryLine
        )
        membershipRecords.append(membership)
        return membership
    }

    // MARK: The day

    func setAttendance(
        playerID: Player.ID, day: Weekday, present: Bool, campID: Camp.ID
    ) async throws -> Camp {
        try mutate(campID) { camp in
            guard camp.player(playerID) != nil else { throw SycamoreError.unknownPlayer }
            camp.setAttendance(playerID: playerID, day: day, present: present)
        }
    }

    func setEarlyPickup(
        playerID: Player.ID, day: Weekday, leavesAt: TimeOfDay?, campID: Camp.ID
    ) async throws -> Camp {
        try mutate(campID) { camp in
            guard camp.player(playerID) != nil else { throw SycamoreError.unknownPlayer }
            camp.setEarlyPickup(playerID: playerID, day: day, leavesAt: leavesAt)
        }
    }

    // MARK: Order

    func reorderGroup(
        _ groupID: Group.ID, playerIDs: [Player.ID], campID: Camp.ID
    ) async throws -> Camp {
        try mutate(campID) { camp in
            guard camp.group(groupID) != nil else { throw SycamoreError.unknownGroup }
            camp.reorder(group: groupID, playerIDs: playerIDs)
        }
    }

    func reorderCamp(_ assignments: [RankAssignment], campID: Camp.ID) async throws -> Camp {
        try mutate(campID) { camp in
            for assignment in assignments where camp.venue(assignment.venueID) == nil {
                throw SycamoreError.unknownVenue
            }
            camp.applyRankOrder(assignments)
        }
    }

    func movePlayer(
        _ playerID: Player.ID, toVenue venueID: Venue.ID, group groupID: Group.ID?, campID: Camp.ID
    ) async throws -> Camp {
        try mutate(campID) { camp in
            guard camp.player(playerID) != nil else { throw SycamoreError.unknownPlayer }
            guard camp.venue(venueID) != nil else { throw SycamoreError.unknownVenue }
            camp.movePlayer(playerID, toVenue: venueID, group: groupID)
        }
    }

    func partitionCamp(_ campID: Camp.ID) async throws -> Camp {
        try mutate(campID) { $0.partition() }
    }

    func evenOut(_ campID: Camp.ID) async throws -> Camp {
        try mutate(campID) { $0.evenOut() }
    }

    // MARK: Shape

    func updateVenue(_ venue: Venue, campID: Camp.ID) async throws -> Camp {
        try mutate(campID) { camp in
            guard camp.venue(venue.id) != nil else { throw SycamoreError.unknownVenue }
            camp.upsert(venue)
        }
    }

    func addVenue(campID: Camp.ID) async throws -> Camp {
        try mutate(campID) { camp in
            let index = camp.venues.count
            let icon = Venue.iconOptions[index % Venue.iconOptions.count]
            let template = camp.orderedVenues.last
            camp.upsert(
                Venue(
                    name: "Venue \(index + 1)",
                    subtitle: nil,
                    icon: icon,
                    tint: .suggested(for: icon),
                    groupCount: template?.groupCount ?? 6,
                    coachMin: template?.coachMin ?? 4,
                    coachMax: template?.coachMax ?? 7,
                    playerMin: template?.playerMin ?? 0,
                    playerMax: template?.playerMax ?? 60,
                    sortIndex: index
                )
            )
        }
    }

    func updateStaffRole(_ staffID: StaffMember.ID, role: Role, campID: Camp.ID) async throws -> Camp {
        try mutate(campID) { camp in
            guard camp.staff(staffID) != nil else { throw SycamoreError.unknownStaff }
            camp.setRole(role, forStaff: staffID)
        }
    }

    func assignStaff(
        _ staffID: StaffMember.ID, toGroup groupID: Group.ID?, campID: Camp.ID
    ) async throws -> Camp {
        try mutate(campID) { camp in
            guard camp.staff(staffID) != nil else { throw SycamoreError.unknownStaff }
            if let groupID, camp.group(groupID) == nil { throw SycamoreError.unknownGroup }
            camp.assignStaff(staffID, toGroup: groupID)
        }
    }

    func removeStaff(_ staffID: StaffMember.ID, campID: Camp.ID) async throws -> Camp {
        try mutate(campID) { camp in
            guard camp.staff(staffID) != nil else { throw SycamoreError.unknownStaff }
            camp.removeStaff(staffID)
        }
    }

    // MARK: Plumbing

    private func mutate(_ campID: Camp.ID, _ edit: (inout Camp) throws -> Void) throws -> Camp {
        guard var camp = camps[campID] else { throw SycamoreError.unknownCamp }
        try edit(&camp)
        camp.reindex()
        camps[campID] = camp
        refreshMembershipProjections(for: camp)
        return camp
    }

    /// Keeps the camp picker's denormalised copies honest after a write.
    private func refreshMembershipProjections(for camp: Camp) {
        for index in membershipRecords.indices where membershipRecords[index].campID == camp.id {
            membershipRecords[index].campName = camp.name
            membershipRecords[index].campIcon = camp.icon
            membershipRecords[index].campTint = camp.tint

            let accountID = membershipRecords[index].accountID
            guard let record = camp.staff.first(where: { $0.accountID == accountID }),
                  let assignment = record.assignment,
                  let court = camp.group(assignment.groupID)
            else {
                membershipRecords[index].todayAssignment = nil
                membershipRecords[index].campSummary = camp.summaryLine
                continue
            }
            membershipRecords[index].role = record.role
            membershipRecords[index].campSummary = nil
            membershipRecords[index].todayAssignment = TodayAssignment(
                venueID: assignment.venueID,
                venueName: assignment.venueName,
                venueIcon: assignment.venueIcon,
                venueTint: camp.venue(assignment.venueID)?.tint ?? camp.tint,
                groupID: court.id,
                groupLabel: court.label,
                kidCount: court.playerCount,
                presentCount: court.presentCount,
                rankedAt: membershipRecords[index].todayAssignment?.rankedAt
            )
        }
    }

    /// `SYC-4821`, `syc4821` and `SYC 4821` are the same code.
    private static func normalise(_ code: String) -> String {
        code.uppercased().filter { $0.isLetter || $0.isNumber }
    }
}

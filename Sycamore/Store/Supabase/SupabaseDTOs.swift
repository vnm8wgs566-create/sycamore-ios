//
//  SupabaseDTOs.swift
//  Sycamore
//
//  One `Decodable` per relation, and the translation into the domain.
//
//  The two vocabularies do not line up, and pretending they do by decoding straight into
//  `Models.swift` would put database spellings inside the app's types forever. A `site` is a
//  `Venue`. A `coach` is a `StaffMember`. `gender` is `'M'` in Postgres and `.m` in Swift.
//  Every one of those mismatches is resolved here and nowhere else, so a column rename is one
//  file's problem.
//
//  Decoding needs no `CodingKeys`: `SupabaseCoding.decoder()` converts snake case, so a property
//  named `courtLabel` reads `court_label` on its own. Writing goes through `RowValues` rather
//  than these types — see that file for why.
//

import Foundation

// MARK: - Camps and people

struct CampRecord: Decodable, Sendable {
    var id: UUID
    var name: String
    var sport: String
    var inviteCode: String
    var icon: String
    var tint: String
}

struct ProfileRecord: Decodable, Sendable {
    var id: UUID
    var email: String
    var displayName: String
    var emergencyPhone: String?
    var notificationsEnabled: Bool
    var avatarUrl: String?
}

struct MembershipRecord: Decodable, Sendable {
    var id: UUID
    var accountId: UUID
    var campId: UUID
    var role: String
    var roleLabel: String?
}

// MARK: - The camp graph

struct SiteRecord: Decodable, Sendable {
    var id: UUID
    var name: String
    var courtCount: Int
    var campId: UUID?
    var subtitle: String?
    var icon: String
    var tint: String
    var coachMin: Int
    var coachMax: Int
    var playerMin: Int
    var playerMax: Int
    var sortIndex: Int
}

struct GroupRecord: Decodable, Sendable {
    var id: UUID
    var siteId: UUID
    var name: String
    var courtLabel: String?
    var rankOrder: Int
    var activity: String?
}

struct PlayerRecord: Decodable, Sendable {
    var id: UUID
    var firstName: String
    var lastInitial: String?
    var lastName: String?
    var age: Int?
    var gender: String?
    var isReturning: Bool
    var siteId: UUID?
    var groupId: UUID?
}

struct CoachRecord: Decodable, Sendable {
    var id: UUID
    var name: String
    /// "Remove from camp" deactivates rather than deletes — see
    /// `SupabaseRepository.removeStaff(_:campID:)` — so every read of the camp filters on this.
    var active: Bool
    var accountId: UUID?
    var campId: UUID?
    var siteId: UUID?
    var groupId: UUID?
    var role: String
    var roleLabel: String?
    var phone: String?
    var isRoaming: Bool
}

struct AttendanceRecord: Decodable, Sendable {
    var playerId: UUID
    var day: String
    var session: String
    var present: Bool
    var leavesAt: String?
}

/// The ladder. `ratings.rating` is the only column in the schema that holds an order over
/// players, which is why it is what a drag on the Rank tab ends up writing.
struct RatingRecord: Decodable, Sendable {
    var playerId: UUID
    var rating: Double
}

// MARK: - Section eight

struct ScheduleBlockRecord: Decodable, Sendable {
    var id: UUID
    var siteId: UUID
    var day: String
    var startsAt: String
    var endsAt: String?
    var title: String
    var detail: String?
    var status: String
}

/// One row of `schedule_block_coaches`: this coach is on that block.
///
/// Two columns and no more, though the table also carries `created_at`. That column is read as an
/// `order` and never as a value — it is what keeps "Nass & Alina" from becoming "Alina & Nass"
/// between two reads of the same block, since the primary key `(block_id, coach_id)` says nothing
/// about sequence and Postgres is under no obligation to invent one.
struct ScheduleBlockCoachRecord: Decodable, Sendable {
    var blockId: UUID
    var coachId: UUID
}

struct InboxItemRecord: Decodable, Sendable {
    var id: UUID
    var siteId: UUID
    var kind: String
    var title: String
    var detail: String?
    var actionLabel: String?
    var actorId: UUID?
    var playerId: UUID?
    var groupId: UUID?
    var scheduleBlockId: UUID?
    /// Defaulted rather than required, so a build that has not applied the migration adding the
    /// column decodes the rest of the row instead of failing every Inbox read.
    var pinned: Bool = false
    var resolved: Bool
    var createdAt: Date
}

/// `select=id` against any relation that has one.
///
/// For asking whether a row is *there* without caring what is in it — which is the one question
/// that separates "no such row" from "a policy would not let you write to that row". See
/// `SupabaseRepository.missingOrRefused(_:id:)`.
struct RowIDRecord: Decodable, Sendable {
    var id: UUID
}

// MARK: - Closed sets

/// The four `text` columns the schema constrains to a fixed list, both ways.
///
/// An unknown value falls back rather than throwing. These are CHECK-constrained columns, so an
/// unrecognised one means the database has grown a case this build of the app predates — and a
/// camp that will not open at all is a worse answer to that than a venue drawn in the wrong
/// green.
enum PostgresEnum {

    static func sport(_ raw: String) -> Sport {
        switch raw {
        case "tennis": .tennis
        case "soccer": .soccer
        case "basketball": .basketball
        case "swim": .swim
        default: .other(label: "")
        }
    }

    /// `Sport.other(label:)` loses its label on the way down: `camps` has a `sport` column and no
    /// `sport_label`, where `memberships` and `coaches` were given both for `role`. A camp created
    /// with a custom sport reads back as plain "Other", and its courts are called Groups.
    static func text(_ sport: Sport) -> String {
        switch sport {
        case .tennis: "tennis"
        case .soccer: "soccer"
        case .basketball: "basketball"
        case .swim: "swim"
        case .other: "other"
        }
    }

    /// `role_label` only carries a value when `role` is `other`, which the table's own CHECK
    /// enforces for `memberships`.
    static func role(_ raw: String, label: String?) -> Role {
        switch raw {
        case "admin": .admin
        case "trainer": .trainer
        case "other": .other(label: label ?? "")
        default: .worker
        }
    }

    static func text(_ role: Role) -> String {
        switch role {
        case .admin: "admin"
        case .worker: "worker"
        case .trainer: "trainer"
        case .other: "other"
        }
    }

    static func label(_ role: Role) -> String? {
        guard case .other(let label) = role else { return nil }
        let trimmed = label.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func tint(_ raw: String) -> VenueTint {
        VenueTint(rawValue: raw) ?? .moss
    }

    /// Postgres writes `M`/`F`/`X`; `Gender` is `m`/`f`/`x`.
    static func gender(_ raw: String?) -> Gender {
        Gender(rawValue: (raw ?? "x").lowercased()) ?? .x
    }

    static func text(_ gender: Gender) -> String {
        gender.rawValue.uppercased()
    }
}

// MARK: - Into the domain

extension Venue {
    init(_ record: SiteRecord) {
        self.init(
            id: record.id,
            name: record.name,
            subtitle: record.subtitle,
            icon: record.icon,
            tint: PostgresEnum.tint(record.tint),
            groupCount: record.courtCount,
            coachMin: record.coachMin,
            coachMax: record.coachMax,
            playerMin: record.playerMin,
            playerMax: record.playerMax,
            sortIndex: record.sortIndex
        )
    }
}

extension Group {
    /// `number` is the court's 1-based position inside its venue rather than a stored column:
    /// the design writes a court chip as `C3`, meaning the third court here, and `rank_order`
    /// is free to be sparse after a reorder.
    init(_ record: GroupRecord, number: Int, capacity: Int) {
        self.init(
            id: record.id,
            venueID: record.siteId,
            number: number,
            label: record.courtLabel ?? record.name,
            rankOrder: record.rankOrder,
            coachID: nil,
            capacity: capacity,
            activity: record.activity
        )
    }
}

extension Player {
    /// `overallRank` and `courtRank` are the caller's business — they come from the ladder, not
    /// from a column, and only the caller has seen the whole camp's ratings.
    ///
    /// A null age is a kid whose form was never finished, and it now stays null the whole way up:
    /// `Player.age` is optional, so the zero this used to substitute is gone. That zero was not
    /// merely a wrong reading — written back it failed the column's own 4…19 CHECK, so importing a
    /// kid with no age could not round-trip at all.
    init(_ record: PlayerRecord, overallRank: Int, courtRank: Int) {
        self.init(
            id: record.id,
            firstName: record.firstName,
            lastInitial: record.lastInitial ?? "",
            lastName: record.lastName,
            age: record.age,
            gender: PostgresEnum.gender(record.gender),
            isReturning: record.isReturning,
            venueID: record.siteId,
            groupID: record.groupId,
            overallRank: overallRank,
            courtRank: courtRank
        )
    }
}

extension StaffMember {
    /// `assignment` is denormalised — it carries the venue's name and emoji so a court chip
    /// draws without walking the graph — so it can only be built once the venue and court are
    /// in hand.
    init(_ record: CoachRecord, assignment: CourtAssignment?) {
        self.init(
            id: record.id,
            accountID: record.accountId,
            name: record.name,
            role: PostgresEnum.role(record.role, label: record.roleLabel),
            phone: record.phone,
            isRoaming: record.isRoaming,
            assignment: assignment
        )
    }
}

extension Attendance {
    /// Nil for a Saturday, a Sunday, or a row outside the week being read — and nil for a row
    /// that says nothing. `Camp` treats the absence of a record as "here all day and staying to
    /// the end", so a `present = true` row with no pick-up time is not a fact, it is the
    /// default written down, and keeping it would leave the model holding rows its own
    /// mutations delete.
    init?(_ record: AttendanceRecord) {
        guard let day = CampWeek.weekday(from: record.day) else { return nil }
        let leavesAt = record.leavesAt.flatMap { TimeOfDay(postgresTime: $0) }
        guard !record.present || leavesAt != nil else { return nil }
        self.init(playerID: record.playerId, day: day, present: record.present, leavesAt: leavesAt)
    }
}

extension ScheduleBlock {
    /// Two of the block's fields are not in its row, and both arrive as arguments.
    ///
    /// `notes` are `inbox_items` of kind `note` carrying this block's `schedule_block_id`;
    /// `coachIDs` are `schedule_block_coaches`. Neither is something a row-to-value initialiser
    /// can go and fetch, so the repository reads all three relations in one wave and hands the
    /// two child lists in — see `scheduleBlocks(forVenue:day:campID:)`, which is where the
    /// previous version of this comment said the decision belonged.
    ///
    /// Both keep a default. `deleteScheduleBlock` decodes the row it removed only to learn which
    /// day to re-read, and a block built to answer that question has no children to supply.
    init?(
        _ record: ScheduleBlockRecord,
        notes: [BlockNote] = [],
        coachIDs: [StaffMember.ID] = []
    ) {
        guard let day = CampWeek.weekday(from: record.day),
              let startsAt = TimeOfDay(postgresTime: record.startsAt)
        else { return nil }
        self.init(
            id: record.id,
            venueID: record.siteId,
            day: day,
            startsAt: startsAt,
            endsAt: record.endsAt.flatMap { TimeOfDay(postgresTime: $0) },
            title: record.title,
            detail: record.detail,
            status: ScheduleBlockStatus(rawValue: record.status) ?? .planned,
            notes: notes,
            coachIDs: coachIDs
        )
    }
}

extension InboxItem {
    init(_ record: InboxItemRecord) {
        self.init(
            id: record.id,
            venueID: record.siteId,
            kind: InboxKind(rawValue: record.kind) ?? .activity,
            title: record.title,
            detail: record.detail,
            actionLabel: record.actionLabel,
            actorID: record.actorId,
            playerID: record.playerId,
            groupID: record.groupId,
            scheduleBlockID: record.scheduleBlockId,
            pinned: record.pinned,
            resolved: record.resolved,
            createdAt: record.createdAt
        )
    }
}

extension HistoryEvent {
    /// The player sheet's timeline. There is no `history` table; what the design draws there —
    /// "Austin Zheng → Court 2", "Nass pinned a note" — is exactly what `inbox_items` already
    /// records against a player, so the timeline is that feed narrowed to one kid.
    init?(_ record: InboxItemRecord) {
        guard let playerID = record.playerId else { return nil }
        self.init(
            id: record.id,
            playerID: playerID,
            title: record.title,
            detail: record.detail ?? "",
            // The blue dot marks what still wants somebody, which is what an unresolved
            // needs-action row is and what a note or a piece of history never is.
            isAccent: record.kind == InboxKind.needsAction.rawValue && !record.resolved,
            at: record.createdAt
        )
    }
}

extension Account {
    init(_ record: ProfileRecord) {
        self.init(
            id: record.id,
            email: record.email,
            // A profile row is created the moment somebody verifies a code, before they have
            // been asked their name, so the local part of the address stands in the way the
            // offline build does.
            displayName: record.displayName.isEmpty
                ? (record.email.split(separator: "@").first.map(String.init)?.capitalized ?? "You")
                : record.displayName,
            avatarImageData: nil,
            emergencyPhone: record.emergencyPhone,
            notificationsEnabled: record.notificationsEnabled
        )
    }
}

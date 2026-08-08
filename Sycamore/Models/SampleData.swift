//
//  SampleData.swift
//  Sycamore
//
//  The design's camp, reproduced. Every number a screen prints — "All 100",
//  "50 kids", "8 here", "1–50", "45 more in Sycamore", "Staff 14", "3 venues · 74 kids"
//  — is derived from the rows below rather than typed into a label, so the sample data
//  and the UI can never disagree.
//

import Foundation

enum SampleData {

    // MARK: - Stable identifiers
    //
    // Deterministic UUIDs keep previews and snapshots identical between launches.

    private enum Kind: Int {
        case account = 1, membership, camp, venue, group, player, staff, history
    }

    /// `00000000-0000-0000-KKKK-IIIIIIIIIIII`, with the kind and the index spelled out
    /// as their own decimal digits — `id(.player, 74)` ends `…-000000000074` — so a
    /// fixture stays recognisable in a debugger or a diff. The bytes are laid out here
    /// rather than parsed back out of a formatted string, which makes the identifier
    /// impossible to fail to construct; the values are the ones every earlier build
    /// produced.
    private static func id(_ kind: Kind, _ index: Int) -> UUID {
        let kindDigits = digitsAsNibbles(kind.rawValue)
        let indexDigits = digitsAsNibbles(index)
        func byte(_ packed: UInt64, _ position: UInt64) -> UInt8 {
            UInt8(truncatingIfNeeded: packed >> (position * 8))
        }
        return UUID(uuid: (
            0, 0, 0, 0, 0, 0, 0, 0,
            byte(kindDigits, 1), byte(kindDigits, 0),
            byte(indexDigits, 5), byte(indexDigits, 4), byte(indexDigits, 3),
            byte(indexDigits, 2), byte(indexDigits, 1), byte(indexDigits, 0)
        ))
    }

    /// The decimal digits of `value`, one per hex nibble: 74 becomes `0x74`. Digits
    /// beyond the sixteenth are dropped rather than overflowing — no fixture is
    /// anywhere near a quadrillion rows, and a total function keeps `id` total.
    private static func digitsAsNibbles(_ value: Int) -> UInt64 {
        var packed: UInt64 = 0
        var remaining = value.magnitude
        var nibble: UInt64 = 0
        while remaining > 0, nibble < 16 {
            packed |= UInt64(remaining % 10) << (nibble * 4)
            remaining /= 10
            nibble += 1
        }
        return packed
    }

    // MARK: - Account

    /// The person the design is signed in as.
    static let account = Account(
        id: id(.account, 1),
        email: "alex@uclacamp.org",
        displayName: "Alex Ramos",
        avatarImageData: nil,
        emergencyPhone: "(310) 555-0106",
        notificationsEnabled: true
    )

    // MARK: - Camps

    static let uclaTennisCamp: Camp = makeUCLATennisCamp()
    static let westsideSwim: Camp = makeWestsideSwim()

    static var camps: [Camp] { [uclaTennisCamp, westsideSwim] }

    // MARK: - Memberships

    /// Alex coaches at UCLA and administers Westside — the same login, two permissions.
    static let uclaMembership = Membership(
        id: id(.membership, 1),
        accountID: account.id,
        campID: uclaTennisCamp.id,
        role: .worker,
        todayAssignment: TodayAssignment(
            venueID: sycamore.id,
            venueName: sycamore.name,
            venueIcon: sycamore.icon,
            venueTint: sycamore.tint,
            groupID: alexsCourt.id,
            groupLabel: alexsCourt.label,
            kidCount: alexsCourt.playerCount,
            presentCount: alexsCourt.presentCount,
            rankedAt: rankedAtToday
        ),
        campName: uclaTennisCamp.name,
        campIcon: uclaTennisCamp.icon,
        campTint: uclaTennisCamp.tint,
        campSummary: nil
    )

    static let westsideMembership = Membership(
        id: id(.membership, 2),
        accountID: account.id,
        campID: westsideSwim.id,
        role: .admin,
        todayAssignment: nil,
        campName: westsideSwim.name,
        campIcon: westsideSwim.icon,
        campTint: westsideSwim.tint,
        campSummary: westsideSwim.summaryLine
    )

    static var memberships: [Membership] { [uclaMembership, westsideMembership] }

    // MARK: - Shortcuts the previews reach for

    static var sycamore: Venue { uclaTennisCamp.venues[0] }
    static var latc: Venue { uclaTennisCamp.venues[1] }

    /// Nass's court — the expanded card in the design.
    static var nassCourt: Group { uclaTennisCamp.groups(in: sycamore.id)[0] }
    /// Hubert's court — the collapsed card carrying "1 over — move one kid down".
    static var hubertsCourt: Group { uclaTennisCamp.groups(in: sycamore.id)[1] }
    /// Alex's court — "8 kids · 7 here".
    static var alexsCourt: Group { uclaTennisCamp.groups(in: sycamore.id)[2] }

    static var sereneC: Player { uclaTennisCamp.orderedPlayers[0] }
    /// The kid every sheet in stage 3 is about.
    static var austinZ: Player { uclaTennisCamp.orderedPlayers[2] }
    /// The away kid on Nass's court.
    static var liamJ: Player { uclaTennisCamp.orderedPlayers[4] }

    static var nass: StaffMember { uclaTennisCamp.staff[0] }
    /// Alex's own staff record — the subject of the staff sheet.
    static var alexStaff: StaffMember { uclaTennisCamp.staff[2] }
    static var dana: StaffMember { uclaTennisCamp.staff[3] }
    static var marisol: StaffMember { uclaTennisCamp.staff[4] }

    // MARK: - UCLA Tennis Camp

    private static func makeUCLATennisCamp() -> Camp {
        let sycamoreID = id(.venue, 1)
        let latcID = id(.venue, 2)

        let sycamore = Venue(
            id: sycamoreID,
            name: "Sycamore",
            subtitle: "Higher level",
            icon: "🌳",
            tint: .moss,
            groupCount: 6,
            coachMin: 4,
            coachMax: 7,
            playerMin: 40,
            playerMax: 60,
            sortIndex: 0
        )
        // LATC needs one coach per court, so four on site reads as "2 coaches short".
        let latc = Venue(
            id: latcID,
            name: "LATC",
            subtitle: nil,
            icon: "🎾",
            tint: .citron,
            groupCount: 6,
            coachMin: 6,
            coachMax: 8,
            playerMin: 40,
            playerMax: 60,
            sortIndex: 1
        )

        // 50 kids over 6 courts is 8 apiece with two left over, so 8 is the working
        // ceiling — which is what makes a court of nine read "1 over".
        let courtCapacity = 8

        let sycamoreCourts = (1...6).map { number in
            Group(
                id: id(.group, number),
                venueID: sycamoreID,
                number: number,
                label: "Court \(number)",
                rankOrder: number,
                coachID: nil,
                capacity: courtCapacity
            )
        }
        let latcCourts = (1...6).map { number in
            Group(
                id: id(.group, 10 + number),
                venueID: latcID,
                number: number,
                label: "Court \(number)",
                rankOrder: number,
                coachID: nil,
                capacity: courtCapacity
            )
        }

        // Which overall ranks sit on which court. Courts are not clean rank blocks —
        // coaches move kids, which is why Jacob N is fourth in the camp but not fourth
        // on Nass's court, and why Austin Z's history reads "Moved up to Court 1".
        let sycamoreLadders: [[Int]] = [
            [1, 2, 3, 5, 7, 9, 11, 13, 15],
            [4, 6, 8, 10, 12, 14, 16, 17, 18],
            Array(19...26),
            Array(27...34),
            Array(35...42),
            Array(43...50),
        ]
        let latcLadders: [[Int]] = [
            Array(51...59),
            Array(60...68),
            Array(69...76),
            Array(77...84),
            Array(85...92),
            Array(93...100),
        ]

        var seat: [Int: (venueID: UUID, groupID: UUID, courtRank: Int)] = [:]
        for (index, ladder) in sycamoreLadders.enumerated() {
            for (position, rank) in ladder.enumerated() {
                seat[rank] = (sycamoreID, sycamoreCourts[index].id, position + 1)
            }
        }
        for (index, ladder) in latcLadders.enumerated() {
            for (position, rank) in ladder.enumerated() {
                seat[rank] = (latcID, latcCourts[index].id, position + 1)
            }
        }

        let fillers = fillerSeeds(
            count: 100 - namedPlayers.count,
            seed: 4821,
            excluding: Set(namedPlayers.values.map { "\($0.firstName) \($0.lastInitial)" })
        )

        var filler = 0
        let players: [Player] = (1...100).map { rank in
            let seed: PlayerSeed
            if let named = namedPlayers[rank] {
                seed = named
            } else {
                seed = fillers[filler]
                filler += 1
            }
            let spot = seat[rank]!
            return Player(
                id: id(.player, rank),
                firstName: seed.firstName,
                lastInitial: seed.lastInitial,
                age: seed.age,
                gender: seed.gender,
                isReturning: seed.isReturning,
                venueID: spot.venueID,
                groupID: spot.groupID,
                overallRank: rank,
                courtRank: spot.courtRank
            )
        }

        func post(_ venue: Venue, _ court: Group) -> CourtAssignment {
            CourtAssignment(
                venueID: venue.id,
                venueName: venue.name,
                venueIcon: venue.icon,
                groupID: court.id,
                groupNumber: court.number,
                groupLabel: court.label
            )
        }

        // Order matters: Setup's staff card shows this list unfiltered, and the design
        // leads with the two admins, then Alex, then the roamer and the front desk.
        let staff: [StaffMember] = [
            StaffMember(id: id(.staff, 1), accountID: nil, name: "Nass", role: .admin,
                        phone: "(310) 555-0101", isRoaming: false,
                        assignment: post(sycamore, sycamoreCourts[0])),
            StaffMember(id: id(.staff, 2), accountID: nil, name: "Hubert", role: .admin,
                        phone: "(310) 555-0102", isRoaming: false,
                        assignment: post(sycamore, sycamoreCourts[1])),
            StaffMember(id: id(.staff, 3), accountID: account.id, name: "Alex", role: .worker,
                        phone: "(310) 555-0106", isRoaming: false,
                        assignment: post(sycamore, sycamoreCourts[2])),
            StaffMember(id: id(.staff, 4), accountID: nil, name: "Dana", role: .trainer,
                        phone: "(310) 555-0103", isRoaming: true, assignment: nil),
            StaffMember(id: id(.staff, 5), accountID: nil, name: "Marisol",
                        role: .other(label: "front desk"),
                        phone: "(310) 555-0104", isRoaming: false, assignment: nil),
            StaffMember(id: id(.staff, 6), accountID: nil, name: "Priya", role: .worker,
                        phone: "(310) 555-0107", isRoaming: false,
                        assignment: post(sycamore, sycamoreCourts[3])),
            StaffMember(id: id(.staff, 7), accountID: nil, name: "Tomas", role: .worker,
                        phone: "(310) 555-0108", isRoaming: false,
                        assignment: post(sycamore, sycamoreCourts[4])),
            StaffMember(id: id(.staff, 8), accountID: nil, name: "Renée", role: .worker,
                        phone: "(310) 555-0109", isRoaming: false,
                        assignment: post(sycamore, sycamoreCourts[5])),
            StaffMember(id: id(.staff, 9), accountID: nil, name: "Kai", role: .worker,
                        phone: "(310) 555-0110", isRoaming: false,
                        assignment: post(latc, latcCourts[0])),
            StaffMember(id: id(.staff, 10), accountID: nil, name: "Mira", role: .worker,
                        phone: "(310) 555-0111", isRoaming: false,
                        assignment: post(latc, latcCourts[1])),
            StaffMember(id: id(.staff, 11), accountID: nil, name: "Owen", role: .worker,
                        phone: "(310) 555-0112", isRoaming: false,
                        assignment: post(latc, latcCourts[2])),
            StaffMember(id: id(.staff, 12), accountID: nil, name: "Sofia", role: .worker,
                        phone: "(310) 555-0113", isRoaming: false,
                        assignment: post(latc, latcCourts[3])),
            StaffMember(id: id(.staff, 13), accountID: nil, name: "Yusuf", role: .worker,
                        phone: "(310) 555-0114", isRoaming: false, assignment: nil),
            StaffMember(id: id(.staff, 14), accountID: nil, name: "Bea",
                        role: .other(label: "nurse"),
                        phone: "(310) 555-0115", isRoaming: false, assignment: nil),
        ]

        // Sparse — only the kids who are not simply here all day.
        // Away: Liam J (rank 5) on Nass's court, one on Alex's, two at LATC. That gives
        // Nass "8 here" out of nine and Alex "8 kids · 7 here".
        let attendance: [Attendance] = [
            Attendance(playerID: id(.player, 5), day: .wed, present: false, leavesAt: nil),
            Attendance(playerID: id(.player, 22), day: .wed, present: false, leavesAt: nil),
            Attendance(playerID: id(.player, 55), day: .wed, present: false, leavesAt: nil),
            Attendance(playerID: id(.player, 62), day: .wed, present: false, leavesAt: nil),
            Attendance(playerID: id(.player, 3), day: .wed, present: true, leavesAt: TimeOfDay(14, 30)),
            Attendance(playerID: id(.player, 30), day: .wed, present: true, leavesAt: TimeOfDay(13, 30)),
        ]

        let history: [HistoryEvent] = [
            HistoryEvent(
                id: id(.history, 1),
                playerID: id(.player, 3),
                title: "Moved up to Sycamore · Court 1",
                detail: "Tuesday · Alex, approved by Nass",
                isAccent: true,
                at: moment(month: 8, day: 4, hour: 16, minute: 40)
            ),
            HistoryEvent(
                id: id(.history, 2),
                playerID: id(.player, 3),
                title: "Ranked into today's order",
                detail: "This morning · Nass",
                isAccent: false,
                at: moment(
                    month: 8, day: 5, hour: rankedAtToday.hour, minute: rankedAtToday.minute
                )
            ),
        ]

        var camp = Camp(
            id: id(.camp, 1),
            name: "UCLA Tennis Camp",
            sport: .tennis,
            inviteCode: "SYC-4821",
            icon: "🌳",
            tint: .moss,
            venues: [sycamore, latc],
            groups: sycamoreCourts + latcCourts,
            players: players,
            staff: staff,
            attendance: attendance,
            history: history
        )
        camp.reindex()
        return camp
    }

    // MARK: - Westside Swim
    //
    // The second camp exists so "Switch camp" has somewhere to go and so the picker's
    // "3 venues · 74 kids" is a fact rather than a caption.

    private static func makeWestsideSwim() -> Camp {
        let pools: [(name: String, icon: String, tint: VenueTint, kids: Int)] = [
            ("North Pool", "🏊", .sky, 25),
            ("South Pool", "🌊", .sky, 25),
            ("Rec Center", "⭐", .moss, 24),
        ]

        var venues: [Venue] = []
        var groups: [Group] = []
        for (index, pool) in pools.enumerated() {
            let venueID = id(.venue, 11 + index)
            venues.append(
                Venue(
                    id: venueID,
                    name: pool.name,
                    subtitle: nil,
                    icon: pool.icon,
                    tint: pool.tint,
                    groupCount: 4,
                    coachMin: 3,
                    coachMax: 5,
                    playerMin: 18,
                    playerMax: 32,
                    sortIndex: index
                )
            )
            for lane in 1...4 {
                groups.append(
                    Group(
                        id: id(.group, 100 + index * 10 + lane),
                        venueID: venueID,
                        number: lane,
                        label: "Lane \(lane)",
                        rankOrder: lane,
                        coachID: nil,
                        capacity: 7
                    )
                )
            }
        }

        let fillers = fillerSeeds(count: 74, seed: 1176, excluding: [])
        var rank = 0
        var players: [Player] = []
        for (index, pool) in pools.enumerated() {
            for _ in 0..<pool.kids {
                let seed = fillers[rank]
                rank += 1
                players.append(
                    Player(
                        id: id(.player, 1000 + rank),
                        firstName: seed.firstName,
                        lastInitial: seed.lastInitial,
                        age: seed.age,
                        gender: seed.gender,
                        isReturning: seed.isReturning,
                        venueID: venues[index].id,
                        groupID: nil,
                        overallRank: rank,
                        courtRank: 0
                    )
                )
            }
        }

        let names = ["Alex", "Rosa", "Jun", "Kwame", "Ingrid", "Petra", "Sol", "Wendell"]
        let staff: [StaffMember] = names.enumerated().map { index, name in
            StaffMember(
                id: id(.staff, 101 + index),
                accountID: index == 0 ? account.id : nil,
                name: name,
                role: index == 0 ? .admin : .worker,
                phone: index == 0 ? account.emergencyPhone : "(310) 555-02\(String(format: "%02d", index))",
                isRoaming: false,
                assignment: nil
            )
        }

        var camp = Camp(
            id: id(.camp, 2),
            name: "Westside Swim",
            sport: .swim,
            inviteCode: "WSW-1176",
            icon: "🏊",
            tint: .sky,
            venues: venues,
            groups: groups,
            players: players,
            staff: staff,
            attendance: [],
            history: []
        )

        // Deal each pool's kids across its lanes, then post the workers to the first
        // lanes so two of the three pools sit inside their coach range.
        for venue in camp.orderedVenues { camp.redistribute(in: venue.id) }
        camp.reindex()

        var cursor = 1
        for venue in camp.orderedVenues {
            for lane in camp.groups(in: venue.id).prefix(3) {
                guard cursor < staff.count else { break }
                let staffID = camp.staff[cursor].id
                camp.assignStaff(staffID, toGroup: lane.id)
                cursor += 1
            }
        }
        camp.reindex()
        return camp
    }

    // MARK: - Player seeds

    private struct PlayerSeed {
        var firstName: String
        var lastInitial: String
        var age: Int
        var gender: Gender
        var isReturning: Bool
    }

    /// A fixed-sequence generator. Deterministic so the roster, the Boys/Girls split
    /// and every age are identical on every launch — previews and screenshots do not
    /// drift.
    private struct SeededRandom {
        private var state: UInt64

        init(seed: UInt64) { state = seed }

        mutating func next(_ bound: Int) -> Int {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Int((state >> 33) % UInt64(max(1, bound)))
        }
    }

    /// Fills the ranks the design does not name. Every first name/initial pair is
    /// handed out at most once, and the name always matches the gender, so a coach
    /// reading a court sees a plausible roster rather than filler.
    ///
    /// A handful are `.x`, and that is deliberate rather than decorative. The camp had none at
    /// all until now — every seeded kid was `.m` or `.f` — so the third gender mark was drawn,
    /// tested and shipped without ever appearing on a screen anybody looked at, in the app or in
    /// a preview. A fixture that cannot produce a state is a fixture that hides it.
    private static func fillerSeeds(
        count: Int, seed: UInt64, excluding taken: Set<String>
    ) -> [PlayerSeed] {
        var combinations: [(name: String, initial: String, gender: Gender)] = []
        for name in boyNames {
            for initial in lastInitials { combinations.append((name, initial, .m)) }
        }
        for name in girlNames {
            for initial in lastInitials { combinations.append((name, initial, .f)) }
        }
        // Drawn from both lists, because `.x` is an answer a camp gives about a kid and not a
        // separate set of names. Few enough that a court still reads as a real roster.
        for name in unspecifiedNames {
            for initial in lastInitials { combinations.append((name, initial, .x)) }
        }

        var random = SeededRandom(seed: seed)
        for index in stride(from: combinations.count - 1, to: 0, by: -1) {
            combinations.swapAt(index, random.next(index + 1))
        }

        var seeds: [PlayerSeed] = []
        for combination in combinations {
            guard seeds.count < count else { break }
            guard !taken.contains("\(combination.name) \(combination.initial)") else { continue }
            seeds.append(
                PlayerSeed(
                    firstName: combination.name,
                    lastInitial: combination.initial,
                    age: 9 + random.next(7),
                    gender: combination.gender,
                    isReturning: random.next(3) == 0
                )
            )
        }
        return seeds
    }

    /// Everyone the design writes by name, at the rank the design gives them.
    private static let namedPlayers: [Int: PlayerSeed] = [
        1: PlayerSeed(firstName: "Serene", lastInitial: "C", age: 13, gender: .f, isReturning: true),
        2: PlayerSeed(firstName: "Liam", lastInitial: "P", age: 12, gender: .m, isReturning: false),
        3: PlayerSeed(firstName: "Austin", lastInitial: "Z", age: 13, gender: .m, isReturning: false),
        4: PlayerSeed(firstName: "Jacob", lastInitial: "N", age: 14, gender: .m, isReturning: false),
        5: PlayerSeed(firstName: "Liam", lastInitial: "J", age: 14, gender: .m, isReturning: true),
        50: PlayerSeed(firstName: "Isla", lastInitial: "M", age: 10, gender: .f, isReturning: false),
        51: PlayerSeed(firstName: "Hugo", lastInitial: "C", age: 13, gender: .m, isReturning: false),
        52: PlayerSeed(firstName: "Lena", lastInitial: "B", age: 14, gender: .f, isReturning: false),
    ]

    private static let boyNames = [
        "Noah", "Ethan", "Caleb", "Diego", "Elias", "Mateo", "Kian", "Rowan", "Felix",
        "Otto", "Jonah", "Milo", "Arjun", "Theo", "Sami", "Dov", "Luca", "Reid", "Emre",
        "Bode", "Cyrus", "Lars", "Rafa", "Zane", "Beau",
    ]

    private static let girlNames = [
        "Ava", "Mia", "Zoe", "Nora", "Ruby", "Iris", "June", "Talia", "Sana", "Maya",
        "Nina", "Cleo", "Esme", "Willa", "Freya", "Anika", "Priya", "Hana", "Sadie",
        "Aisha", "Georgia", "Neve", "Tess", "Wren", "Yara",
    ]

    /// The kids whose gender column says `X`.
    ///
    /// A short list on purpose: with `lastInitials` behind it this is 108 of roughly 1,000
    /// combinations, so a fifty-kid venue draws four or five and a court sees one now and then —
    /// enough that the third mark is on screen in the ordinary run of using the app, not so many
    /// that the fixture stops looking like a camp.
    ///
    /// Names that are given to children of any gender, rather than a third set of "other" names,
    /// which would have made the fixture assert something about people that the column does not.
    private static let unspecifiedNames = [
        "Rio", "Sage", "Ari", "Quinn", "Remy", "Alex",
    ]

    private static let lastInitials = [
        "A", "B", "C", "D", "F", "G", "H", "K", "L", "M",
        "N", "P", "R", "S", "T", "V", "W", "Z",
    ]

    // MARK: - Fixed clock
    //
    // The offline build's "today" is Wednesday 5 August 2026, which is what makes
    // "Tuesday" and "This morning" in Austin Z's timeline line up.

    /// When this morning's order was committed. One value, spelled `9:12am` by
    /// `TodayAssignment.summaryLine` and stamped on Austin Z's "Ranked into today's
    /// order" event, so the timeline and the profile card can never drift apart.
    static let rankedAtToday = TimeOfDay(9, 12)

    private static func moment(month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles") ?? TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(
            year: 2026, month: month, day: day, hour: hour, minute: minute
        )
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }
}

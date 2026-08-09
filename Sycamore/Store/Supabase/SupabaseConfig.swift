//
//  SupabaseConfig.swift
//  Sycamore
//
//  Where the app points, and the one key it carries.
//
//  The key is a *publishable* key, which is the kind Supabase designs to ship inside a client
//  binary — it grants exactly what row level security grants `anon` and nothing more. It is not
//  a secret and there is no point hiding it in a plist the same person can `strings`; the thing
//  that has to be right is the RLS policy behind it, not the storage of the key.
//
//  One file so a fork or a staging project is a single edit. Nothing else in `Supabase/` spells
//  a URL.
//

import Foundation

enum SupabaseConfig {

    static let projectURL = URL(string: "https://zygjbyxlyghemagcpqgx.supabase.co")!

    static let publishableKey = "sb_publishable_OeUuGsWAkqusxKFmCjTzmw_nrV9c-8T"

    /// PostgREST. Every table and view hangs directly off this.
    static var restURL: URL { projectURL.appending(path: "rest/v1") }

    /// GoTrue.
    static var authURL: URL { projectURL.appending(path: "auth/v1") }

    /// Long enough that a coach on camp wifi is not told the network failed while it is merely
    /// slow, short enough that a dead connection does not hold a sheet open for a minute.
    static let requestTimeout: TimeInterval = 20
}

// MARK: - Table names

/// The relations this client touches, spelled once.
///
/// The app and this database were named from opposite ends: what the app calls a `Venue` is a
/// `site` here, and what it calls a `StaffMember` is a `coach`. Keeping both vocabularies alive
/// in string literals scattered through the repository is how the two drift, so the translation
/// happens here and nowhere else.
enum Relation {
    static let camps = "camps"
    static let profiles = "profiles"
    static let memberships = "memberships"
    /// `Venue`.
    static let sites = "sites"
    static let groups = "groups"
    static let players = "players"
    /// `StaffMember`.
    static let coaches = "coaches"
    static let attendance = "attendance"
    static let ratings = "ratings"
    /// Never written by this app — `coaches.group_id` is where a court assignment lives now —
    /// but rows already here reference `groups`, so dropping a court has to clear them.
    static let courtAssignments = "court_assignments"
    static let assessments = "assessments"
    static let scheduleBlocks = "schedule_blocks"
    /// Who is running a block. A join table rather than a `coach_id` on `schedule_blocks`,
    /// because the design writes "Nass & Alina" on one card — a block can have more than one
    /// coach on it, and a single column could only ever say the first of them.
    static let scheduleBlockCoaches = "schedule_block_coaches"
    /// Which courts a block runs on. A join table for the same reason its sibling above is one —
    /// a block runs on several courts and a single column could name only the first — and the
    /// replacement for the courts that used to live inside `schedule_blocks.detail`, where nothing
    /// could read them back.
    static let scheduleBlockCourts = "schedule_block_courts"
    static let inboxItems = "inbox_items"
}

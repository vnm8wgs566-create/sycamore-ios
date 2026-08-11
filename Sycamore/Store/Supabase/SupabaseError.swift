//
//  SupabaseError.swift
//  Sycamore
//
//  What can go wrong between here and Postgres, as opposed to what can go wrong inside the camp.
//
//  `SycamoreError` names the domain's failures — no such camp, only an admin can do that — and
//  the repository keeps throwing those wherever one fits, because they are the sentences the
//  error banner is written to show. This type covers the layer underneath: the request that
//  never left, the row that came back malformed, the 403 that means the policy disagrees with
//  us. A coach should still get a readable line out of every one of them.
//

import Foundation

enum SupabaseError: LocalizedError, Equatable {

    /// The request never completed — no wifi on court 6, DNS, a timeout.
    case offline(String)
    /// PostgREST or GoTrue answered, and said no. `message` is their own `message`/`msg` field,
    /// which is written for a developer but is the only specific thing we have.
    case rejected(status: Int, message: String)
    /// A 200 whose body is not the shape this client expects. Almost always a schema change
    /// that landed without the client, which is worth saying plainly rather than as "nil".
    case malformedResponse(String)
    /// A write that needs a signed-in person, attempted without one.
    case notSignedIn
    /// A `PATCH` or `DELETE` built with no filter on it. Caught here rather than sent, because
    /// PostgREST would cheerfully apply it to every row in the table.
    case unfilteredWrite(String)

    var errorDescription: String? {
        switch self {
        case .offline:
            "Can't reach Sycamore. Check your connection and try again."
        case .rejected(let status, let message):
            status == 401 || status == 403
                ? "You don't have access to that."
                : (message.isEmpty ? "The server rejected that (\(status))." : message)
        case .malformedResponse:
            "Sycamore sent something this version can't read. Try updating the app."
        case .notSignedIn:
            "Sign in first."
        case .unfilteredWrite:
            "Sycamore stopped a write that would have changed every row."
        }
    }

    var isOffline: Bool {
        if case .offline = self { return true }
        return false
    }

    /// True when re-sending with a fresh access token is worth a try. Only 401: a 403 is the row
    /// level security policy answering, and it will answer the same way twice.
    var isExpiredCredential: Bool {
        if case .rejected(let status, _) = self { return status == 401 }
        return false
    }

    /// The object is not there, which is a *state* on the one path that asks: a person who has
    /// never set a profile photo has no object in the bucket, and Storage answers 404. Turning
    /// that into a banner would report a failure on a screen doing exactly what it should.
    ///
    /// Deliberately narrow. `StorageClient.fetch` and `.delete` are its only readers, and every
    /// other status they can raise still throws — a 403 from the owner policy in particular, which
    /// means somebody reached for a folder that is not theirs and is worth hearing about.
    var isNotFound: Bool {
        if case .rejected(let status, _) = self { return status == 404 }
        return false
    }

    /// Postgres raises `23505` for a unique violation, and PostgREST passes the code through in
    /// the message. Two callers need to tell that apart from a real failure and retry with a
    /// different name — `sites.name` and `camps.invite_code` are both globally unique.
    ///
    /// Matched on the code and not on the status: PostgREST answers 409 for a foreign key
    /// violation too, and reading one of those as "that name is taken" would send `insertSite`
    /// through six pointless renames before reporting the wrong thing.
    var isUniqueViolation: Bool {
        if case .rejected(_, let message) = self {
            return message.contains("23505")
                || message.localizedCaseInsensitiveContains("duplicate key")
        }
        return false
    }

    /// The policy answering, as opposed to the token being stale — see `isExpiredCredential`.
    ///
    /// Postgres answers a `with check` violation with 403, and PostgREST passes the status
    /// through. That is a rule refusing a value, not a session refusing a person, and the two
    /// want different sentences: `errorDescription` says "You don't have access to that.", which
    /// reads as a sign-in problem and sends an admin's colleague to the wrong screen. A caller on
    /// an admin-gated write turns this into `SycamoreError.notPermitted` — "Only an admin can do
    /// that." — which is the sentence that was already written for it.
    ///
    /// Matched on the status rather than on Postgres's `42501`, because the two arrive by
    /// different routes: `42501` is a missing *grant* (the `today_courts` view has one), while a
    /// row level security refusal carries no SQLSTATE at all.
    var isPolicyRefusal: Bool {
        if case .rejected(let status, _) = self { status == 403 } else { false }
    }

    /// A `URLSession` failure, classified.
    ///
    /// Cancellation is not a network failure and must not be dressed as one. A screen dismissed
    /// mid-load would raise a banner about the connection, and inside a task group every sibling
    /// cancelled by one real failure would report "can't reach Sycamore" and race to mask the
    /// error that actually happened.
    static func transportFailure(_ error: any Error) -> any Error {
        if error is CancellationError { return error }
        if let urlError = error as? URLError, urlError.code == .cancelled {
            return CancellationError()
        }
        return SupabaseError.offline(error.localizedDescription)
    }
}

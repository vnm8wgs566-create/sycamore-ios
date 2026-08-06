//
//  PostgRESTQueryTests.swift
//  SycamoreTests
//
//  The filter grammar, tested through the only seam that matters: what goes on the wire.
//
//  This layer once shipped a quoting bug that broke every filter in the app at the same time.
//  `?name=eq."Sycamore"` is not a syntax error — PostgREST hands the quotes to Postgres, which
//  compares against a string that has quotes in it, finds nothing, and returns an empty array
//  with a 200. Every screen drew an empty state and nothing anywhere said why.
//
//  So the assertions below are on exact strings. "Contains the column name" would have passed
//  throughout that bug.
//

import Foundation
import Testing
@testable import Sycamore

@Suite("PostgRESTQuery.encoded")
struct PostgRESTQueryTests {

    /// Fixed so the expectations can be written out rather than interpolated back from the
    /// thing under test.
    static let campID = UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")!

    // MARK: Nothing to say

    @Test("An empty query encodes to nothing at all")
    func emptyIsNil() {
        #expect(PostgRESTQuery().encoded == nil)
    }

    // MARK: Scalars are never quoted

    /// The bug. Quoting a scalar is silent: PostgREST accepts it, Postgres compares against a
    /// string containing quote marks, and the answer is an empty result rather than an error.
    @Test("A string filter is bare — quoting it is what broke every filter in the app")
    func scalarsAreNotQuoted() {
        #expect(PostgRESTQuery().eq("name", "Sycamore").encoded == "name=eq.Sycamore")
    }

    @Test("A UUID filter is bare, and its hyphens survive")
    func uuidsAreBare() {
        #expect(
            PostgRESTQuery().eq("id", Self.campID).encoded
                == "id=eq.E621E1F8-C36C-495A-93FC-0C247A3E6E5F"
        )
    }

    @Test("Numbers and booleans render as Postgres literals")
    func numbersAndBooleans() {
        #expect(PostgRESTQuery().eq("rank", 9).encoded == "rank=eq.9")
        #expect(PostgRESTQuery().gte("rank", -3).encoded == "rank=gte.-3")
        #expect(PostgRESTQuery().eq("active", true).encoded == "active=eq.true")
        #expect(PostgRESTQuery().eq("active", false).encoded == "active=eq.false")
    }

    @Test("Every comparison spells its own operator")
    func operators() {
        #expect(PostgRESTQuery().eq("n", 1).encoded == "n=eq.1")
        #expect(PostgRESTQuery().neq("n", 1).encoded == "n=neq.1")
        #expect(PostgRESTQuery().gte("n", 1).encoded == "n=gte.1")
        #expect(PostgRESTQuery().lte("n", 1).encoded == "n=lte.1")
    }

    @Test("A date string keeps its hyphens — they are not grammar to escape around")
    func dateStrings() {
        #expect(PostgRESTQuery().eq("day", "2026-08-05").encoded == "day=eq.2026-08-05")
    }

    // MARK: List elements always are

    @Test("List elements are double-quoted, and the quotes are percent-encoded")
    func listsAreQuoted() {
        #expect(PostgRESTQuery().within("id", ["a", "b"]).encoded == "id=in.(%22a%22,%22b%22)")
    }

    /// The asymmetry in one test: the same value is bare on the left and quoted on the right,
    /// and that is not an inconsistency to tidy up — it is what each side of the grammar takes.
    @Test("The same value is bare in eq and quoted in in")
    func theAsymmetry() {
        #expect(PostgRESTQuery().eq("name", "Sycamore").encoded == "name=eq.Sycamore")
        #expect(PostgRESTQuery().within("name", ["Sycamore"]).encoded == "name=in.(%22Sycamore%22)")
    }

    /// A comma is grammar, so it is deliberately *not* escaped. What keeps a comma inside a
    /// value is the pair of quotes around it — which is the whole reason list elements are
    /// quoted and scalars are not.
    @Test("A comma inside a list value stays inside it, held there by the quotes")
    func commasSurviveInsideAList() {
        #expect(
            PostgRESTQuery().within("name", ["Sycamore, north", "LATC"]).encoded
                == "name=in.(%22Sycamore,%20north%22,%22LATC%22)"
        )
    }

    @Test("A double quote inside a list value is backslash-escaped before encoding")
    func quotesInsideAListValue() {
        #expect(PostgRESTQuery().within("name", ["a\"b"]).encoded == "name=in.(%22a%5C%22b%22)")
    }

    @Test("A backslash inside a list value is doubled, so it cannot escape the closing quote")
    func backslashesInsideAListValue() {
        #expect(PostgRESTQuery().within("name", ["a\\b"]).encoded == "name=in.(%22a%5C%5Cb%22)")
        // The one that matters: a value ending in a backslash must not swallow the quote that
        // closes it and run into the next element.
        #expect(
            PostgRESTQuery().within("name", ["a\\", "b"]).encoded
                == "name=in.(%22a%5C%5C%22,%22b%22)"
        )
    }

    @Test("A list of UUIDs is quoted the same way as a list of strings")
    func uuidLists() {
        #expect(
            PostgRESTQuery().within("id", [Self.campID]).encoded
                == "id=in.(%22E621E1F8-C36C-495A-93FC-0C247A3E6E5F%22)"
        )
    }

    /// PostgREST rejects `in.()`, and `PostgRESTQuery` deliberately does not paper over it — a
    /// caller with nothing to match wants to skip the request, not send one that cannot succeed.
    /// Pinned so the degenerate string stays visible rather than becoming a silent empty query.
    @Test("An empty list encodes to the degenerate form the caller has to avoid")
    func emptyList() {
        #expect(PostgRESTQuery().within("id", [String]()).encoded == "id=in.()")
    }

    // MARK: What must not be escaped

    /// Escaping the grammar would turn a column list into a single, nonexistent column name.
    @Test("select keeps every character PostgREST parses structurally")
    func selectGrammarSurvives() {
        #expect(
            PostgRESTQuery.select("*,players!inner(site_id)").encoded
                == "select=*,players!inner(site_id)"
        )
        #expect(PostgRESTQuery.select("id,name,ratings(rating)").encoded == "select=id,name,ratings(rating)")
    }

    @Test("An embedded resource's dotted column name survives")
    func dottedColumnNames() {
        #expect(
            PostgRESTQuery().within("players.site_id", ["a"]).encoded
                == "players.site_id=in.(%22a%22)"
        )
    }

    /// Grammar characters are never escaped, including in a data position. That is the deal the
    /// design makes, and it is pinned here rather than left to be discovered: a value carrying a
    /// parenthesis reaches PostgREST as a parenthesis.
    @Test("Parentheses in a scalar value pass straight through")
    func parenthesesInAValue() {
        #expect(PostgRESTQuery().eq("name", "Court (main)").encoded == "name=eq.Court%20(main)")
    }

    // MARK: What must be

    /// `URLComponents.queryItems` leaves `+` alone, and a server reads a bare `+` in a query as
    /// a space — which is how the plus in a coach's address becomes a space on the way to
    /// Postgres, and the lookup finds nobody.
    @Test("A plus in an email address is encoded rather than read as a space")
    func plusIsEncoded() {
        #expect(
            PostgRESTQuery().eq("email", "alex+camp@uclacamp.org").encoded
                == "email=eq.alex%2Bcamp%40uclacamp.org"
        )
        #expect(
            PostgRESTQuery().within("email", ["alex+camp@uclacamp.org"]).encoded
                == "email=in.(%22alex%2Bcamp%40uclacamp.org%22)"
        )
    }

    /// Leaving these alone is how one value silently becomes two query items — and a query item
    /// PostgREST does not recognise is a filter it ignores, which means more rows, not fewer.
    @Test("The characters that would split a query item are all encoded")
    func separatorsAreEncoded() {
        #expect(PostgRESTQuery().eq("name", "Rock & Roll").encoded == "name=eq.Rock%20%26%20Roll")
        #expect(PostgRESTQuery().eq("note", "a=b").encoded == "note=eq.a%3Db")
        #expect(PostgRESTQuery().eq("note", "a#b").encoded == "note=eq.a%23b")
        #expect(PostgRESTQuery().eq("note", "a?b").encoded == "note=eq.a%3Fb")
    }

    /// A value that already looks encoded must be encoded again, or `%26` in someone's note
    /// arrives at the server as `&`.
    @Test("A literal percent sign is encoded rather than trusted")
    func percentIsEncoded() {
        #expect(PostgRESTQuery().eq("note", "100%").encoded == "note=eq.100%25")
        #expect(PostgRESTQuery().eq("note", "%26").encoded == "note=eq.%2526")
    }

    @Test("Column names are escaped too, not just values")
    func columnNamesAreEscaped() {
        #expect(PostgRESTQuery().eq("odd col", "1").encoded == "odd%20col=eq.1")
    }

    /// `URLComponents.percentEncodedQuery` is where this string ends up, and it will not accept
    /// one that is not already encoded. A camp has a coach called Renée and venues named with
    /// emoji, so this is not hypothetical.
    @Test("Everything comes out ASCII, whatever went in")
    func outputIsAlwaysASCII() {
        let accented = PostgRESTQuery().eq("name", "Renée").encoded
        #expect(accented == "name=eq.Ren%C3%A9e")

        let emoji = PostgRESTQuery().eq("icon", "🌳").encoded
        #expect(emoji == "icon=eq.%F0%9F%8C%B3")

        for encoded in [accented, emoji].compactMap({ $0 }) {
            #expect(encoded.allSatisfy { $0.isASCII })
        }
    }

    // MARK: Shape

    @Test("Ordering spells the direction and the null placement every time")
    func ordering() {
        #expect(PostgRESTQuery().order("rank_order").encoded == "order=rank_order.asc.nullslast")
        #expect(
            PostgRESTQuery().order("created_at", ascending: false).encoded
                == "order=created_at.desc.nullslast"
        )
        #expect(
            PostgRESTQuery().order("rank", ascending: false, nullsFirst: true).encoded
                == "order=rank.desc.nullsfirst"
        )
    }

    @Test("Limit, is-null and is-true take keywords, not values")
    func keywordFilters() {
        #expect(PostgRESTQuery().limit(25).encoded == "limit=25")
        #expect(PostgRESTQuery().isNull("group_id").encoded == "group_id=is.null")
        #expect(PostgRESTQuery().isNull("group_id", false).encoded == "group_id=not.is.null")
        #expect(PostgRESTQuery().isTrue("active").encoded == "active=is.true")
        #expect(PostgRESTQuery().isTrue("active", false).encoded == "active=is.false")
    }

    @Test("raw passes configuration through as written")
    func rawItems() {
        #expect(
            PostgRESTQuery().raw("on_conflict", "account_id,camp_id").encoded
                == "on_conflict=account_id,camp_id"
        )
    }

    // MARK: Composition

    @Test("Filters join with & in the order they were written")
    func filtersJoinInOrder() {
        let query = PostgRESTQuery
            .select("*,sites!inner(camp_id)")
            .eq("id", Self.campID)
            .eq("sites.camp_id", "abc")
            .order("rank_order")
            .limit(10)

        #expect(
            query.encoded
                == "select=*,sites!inner(camp_id)"
                + "&id=eq.E621E1F8-C36C-495A-93FC-0C247A3E6E5F"
                + "&sites.camp_id=eq.abc"
                + "&order=rank_order.asc.nullslast"
                + "&limit=10"
        )
    }

    /// Every builder method returns a copy. If one ever started mutating in place, a shared
    /// base query would accumulate the filters of every request built from it — and the bug
    /// would depend on the order requests happened to run in.
    @Test("Building from a shared base does not contaminate it")
    func isAValueType() {
        let base = PostgRESTQuery.select("*")
        let players = base.eq("site_id", "one")
        let coaches = base.eq("account_id", "two")

        #expect(base.encoded == "select=*")
        #expect(players.encoded == "select=*&site_id=eq.one")
        #expect(coaches.encoded == "select=*&account_id=eq.two")
    }

    @Test("The same column can be filtered twice, which is how a range is written")
    func repeatedColumns() {
        #expect(
            PostgRESTQuery().gte("rank", 1).lte("rank", 50).encoded
                == "rank=gte.1&rank=lte.50"
        )
    }
}

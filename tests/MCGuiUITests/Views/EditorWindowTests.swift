import Foundation
import Testing
@testable import MCGuiUI
import MCGuiCore

@Suite("EditorWindow find/replace")
struct EditorWindowTests {


    @Test("nextMatch finds the first case-insensitive occurrence at or after the given offset")
    func nextMatchFindsOccurrenceAtOrAfterOffset() {
        let match = EditorWindow.nextMatch(in: "hello World, hello Swift", query: "hello", after: 1)

        #expect(match?.location == 13)
        #expect(match?.length == 5)
    }

    @Test("nextMatch wraps to the first match when none remain after the given offset")
    func nextMatchWrapsAroundToFirstMatch() {
        let match = EditorWindow.nextMatch(in: "hello World, hello Swift", query: "hello", after: 20)

        #expect(match?.location == 0)
    }

    @Test("nextMatch returns nil for an empty query")
    func nextMatchWithEmptyQueryReturnsNil() {
        #expect(EditorWindow.nextMatch(in: "hello World", query: "", after: 0) == nil)
    }

    @Test("nextMatch returns nil when the query is not present")
    func nextMatchWithNoMatchReturnsNil() {
        #expect(EditorWindow.nextMatch(in: "hello World", query: "xyz", after: 0) == nil)
    }


    @Test("replaceAll replaces every case-insensitive occurrence and returns the count")
    func replaceAllReplacesEveryOccurrence() {
        let result = EditorWindow.replaceAll(in: "cat Cat CAT dog", query: "cat", replacement: "cow")

        #expect(result.text == "cow cow cow dog")
        #expect(result.count == 3)
    }

    @Test("replaceAll with no matches returns the original text and a zero count")
    func replaceAllWithNoMatchesReturnsOriginal() {
        let result = EditorWindow.replaceAll(in: "hello World", query: "xyz", replacement: "abc")

        #expect(result.text == "hello World")
        #expect(result.count == 0)
    }

    @Test("replaceAll with an empty query is a no-op")
    func replaceAllWithEmptyQueryIsNoOp() {
        let result = EditorWindow.replaceAll(in: "hello World", query: "", replacement: "abc")

        #expect(result.text == "hello World")
        #expect(result.count == 0)
    }
}

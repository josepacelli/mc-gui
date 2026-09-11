import Foundation
import Testing
@testable import MCGuiCore

@Suite("PathHistoryManager")
struct PathHistoryManagerTests {

    private let a = URL(fileURLWithPath: "/tmp/a")
    private let b = URL(fileURLWithPath: "/tmp/b")
    private let c = URL(fileURLWithPath: "/tmp/c")
    private let d = URL(fileURLWithPath: "/tmp/d")


    @Test("navigate pushes the current path onto past and clears future")
    func navigatePushesPastAndClearsFuture() {
        let history = PanelPathHistory(past: [a], future: [d])

        let result = PathHistoryManager.navigate(to: c, from: b, history: history)

        #expect(result.past == [a, b])
        #expect(result.future == [])
    }

    @Test("navigate from an empty history appends the single current path to past")
    func navigateFromEmptyHistory() {
        let result = PathHistoryManager.navigate(to: b, from: a, history: PanelPathHistory())

        #expect(result.past == [a])
        #expect(result.future == [])
    }


    @Test("back on empty history returns nil")
    func backOnEmptyHistoryReturnsNil() {
        let result = PathHistoryManager.back(from: a, history: PanelPathHistory())

        #expect(result == nil)
    }

    @Test("back with a single past entry returns that path and moves current path to future")
    func backWithSingleEntry() throws {
        let history = PanelPathHistory(past: [a], future: [])

        let result = try #require(PathHistoryManager.back(from: b, history: history))

        #expect(result.path == a)
        #expect(result.history.past == [])
        #expect(result.history.future == [b])
    }

    @Test("back with multiple past entries pops only the most recent one")
    func backWithMultipleEntries() throws {
        let history = PanelPathHistory(past: [a, b], future: [])

        let result = try #require(PathHistoryManager.back(from: c, history: history))

        #expect(result.path == b)
        #expect(result.history.past == [a])
        #expect(result.history.future == [c])
    }


    @Test("forward on empty future returns nil")
    func forwardOnEmptyFutureReturnsNil() {
        let result = PathHistoryManager.forward(from: a, history: PanelPathHistory())

        #expect(result == nil)
    }

    @Test("forward with a single future entry returns that path and moves current path to past")
    func forwardWithSingleEntry() throws {
        let history = PanelPathHistory(past: [], future: [b])

        let result = try #require(PathHistoryManager.forward(from: a, history: history))

        #expect(result.path == b)
        #expect(result.history.past == [a])
        #expect(result.history.future == [])
    }


    @Test("navigating to a new path after going back clears the stale forward stack")
    func navigateAfterBackClearsForward() throws {
        let initialHistory = PanelPathHistory(past: [a, b], future: [])

        let backResult = try #require(PathHistoryManager.back(from: c, history: initialHistory))
        #expect(backResult.path == b)
        #expect(backResult.history.past == [a])
        #expect(backResult.history.future == [c])

        let navigateResult = PathHistoryManager.navigate(to: d, from: backResult.path, history: backResult.history)

        #expect(navigateResult.past == [a, b])
        #expect(navigateResult.future == [])
    }
}

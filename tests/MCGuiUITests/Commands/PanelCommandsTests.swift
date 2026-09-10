import Foundation
import Testing
@testable import MCGuiUI
import MCGuiCore

/// Wiring-level tests for `PanelCommands` (T45): confirms each key action calls through to
/// the right `SelectionService` semantics (already unit-tested in isolation at T9) after
/// translating `PanelView`'s `Set<FileEntry.ID>` selection into `SelectionService`'s
/// `Set<Int>` index space and back.
@Suite("PanelCommands")
struct PanelCommandsTests {

    private let entries = [
        makeTestEntry(name: "a.txt"),
        makeTestEntry(name: "b.txt"),
        makeTestEntry(name: "c.txt")
    ]

    // MARK: - moveCursor (KN-02: arrow keys)

    @Test("moveCursor with no current cursor and a downward delta starts at the first entry")
    func moveCursorWithNoCursorStartsAtFirst() {
        let next = PanelCommands.moveCursor(nil, delta: 1, entries: entries)

        #expect(next == entries[0].id)
    }

    @Test("moveCursor with delta +1 moves to the next entry")
    func moveCursorDownMovesToNextEntry() {
        let next = PanelCommands.moveCursor(entries[0].id, delta: 1, entries: entries)

        #expect(next == entries[1].id)
    }

    @Test("moveCursor at the last entry with delta +1 stays clamped at the last entry")
    func moveCursorDownAtLastEntryStaysClamped() {
        let next = PanelCommands.moveCursor(entries[2].id, delta: 1, entries: entries)

        #expect(next == entries[2].id)
    }

    @Test("moveCursor on an empty list returns nil")
    func moveCursorOnEmptyListReturnsNil() {
        #expect(PanelCommands.moveCursor(nil, delta: 1, entries: []) == nil)
    }

    // MARK: - extendSelection (KN-03: Shift+Arrow), via SelectionService.range

    @Test("extendSelection from the first entry downward selects the range through the new cursor")
    func extendSelectionDownwardSelectsRange() {
        let result = PanelCommands.extendSelection(anchor: entries[0].id, cursor: entries[0].id, delta: 1, entries: entries)

        #expect(result.selection == Set([entries[0].id, entries[1].id]))
        #expect(result.cursor == entries[1].id)
    }

    @Test("extendSelection back toward the anchor shrinks the range")
    func extendSelectionBackTowardAnchorShrinksRange() {
        let expanded = PanelCommands.extendSelection(anchor: entries[0].id, cursor: entries[0].id, delta: 1, entries: entries)
        let shrunk = PanelCommands.extendSelection(anchor: entries[0].id, cursor: expanded.cursor, delta: -1, entries: entries)

        #expect(shrunk.selection == Set([entries[0].id]))
        #expect(shrunk.cursor == entries[0].id)
    }

    // MARK: - jump (KN-04: Cmd+Arrow), via SelectionService.firstIndex/lastIndex

    @Test("jump toFirst returns the first entry's id")
    func jumpToFirstReturnsFirstEntry() {
        #expect(PanelCommands.jump(toFirst: true, entries: entries) == entries[0].id)
    }

    @Test("jump toLast returns the last entry's id")
    func jumpToLastReturnsLastEntry() {
        #expect(PanelCommands.jump(toFirst: false, entries: entries) == entries[2].id)
    }

    @Test("jump on an empty list returns nil")
    func jumpOnEmptyListReturnsNil() {
        #expect(PanelCommands.jump(toFirst: true, entries: []) == nil)
    }

    // MARK: - toggleSelection (KN-05: Space), via SelectionService.toggle

    @Test("toggleSelection selects an unselected entry")
    func toggleSelectionSelectsUnselectedEntry() {
        let result = PanelCommands.toggleSelection([], id: entries[1].id, entries: entries)

        #expect(result == Set([entries[1].id]))
    }

    @Test("toggleSelection deselects an already-selected entry")
    func toggleSelectionDeselectsSelectedEntry() {
        let result = PanelCommands.toggleSelection(Set([entries[1].id]), id: entries[1].id, entries: entries)

        #expect(result.isEmpty)
    }

    @Test("toggleSelection with a nil id leaves the selection unchanged")
    func toggleSelectionWithNilIdIsNoOp() {
        let current = Set([entries[0].id])

        let result = PanelCommands.toggleSelection(current, id: nil, entries: entries)

        #expect(result == current)
    }

    // MARK: - toggleAndAdvance (KN-06: Insert), via SelectionService.toggleAndAdvance

    @Test("toggleAndAdvance selects the entry and advances the cursor to the next one")
    func toggleAndAdvanceSelectsAndAdvances() {
        let result = PanelCommands.toggleAndAdvance([], id: entries[0].id, entries: entries)

        #expect(result.selection == Set([entries[0].id]))
        #expect(result.nextCursor == entries[1].id)
    }

    @Test("toggleAndAdvance at the last entry advances no further (clamped)")
    func toggleAndAdvanceAtLastEntryStaysClamped() {
        let result = PanelCommands.toggleAndAdvance([], id: entries[2].id, entries: entries)

        #expect(result.selection == Set([entries[2].id]))
        #expect(result.nextCursor == entries[2].id)
    }
}

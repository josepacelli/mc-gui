import Testing
@testable import MCGuiCore

@Suite("SelectionService")
struct SelectionServiceTests {

    // MARK: - toggle (KN-05: Space to toggle selection)

    @Test("toggle selects an unselected index")
    func toggleSelectsUnselectedIndex() {
        let result = SelectionService.toggle([], index: 2, count: 5)

        #expect(result == [2])
    }

    @Test("toggle deselects an already-selected index")
    func toggleDeselectsSelectedIndex() {
        let result = SelectionService.toggle([2], index: 2, count: 5)

        #expect(result == [])
    }

    @Test("toggle is a no-op for an out-of-bounds index")
    func toggleIgnoresOutOfBoundsIndex() {
        let result = SelectionService.toggle([1], index: 5, count: 5)

        #expect(result == [1])
    }

    @Test("toggle is a no-op on an empty list")
    func toggleOnEmptyListIsNoOp() {
        let result = SelectionService.toggle([], index: 0, count: 0)

        #expect(result == [])
    }

    // MARK: - range (KN-03: Shift+Arrow for range selection)

    @Test("range selects a contiguous forward span from anchor to index")
    func rangeSelectsForwardSpan() {
        let result = SelectionService.range(anchor: 1, to: 4, count: 10)

        #expect(result == [1, 2, 3, 4])
    }

    @Test("range selects a contiguous backward span when index precedes anchor")
    func rangeSelectsBackwardSpan() {
        let result = SelectionService.range(anchor: 4, to: 1, count: 10)

        #expect(result == [1, 2, 3, 4])
    }

    @Test("range with anchor equal to index selects a single entry")
    func rangeWithEqualAnchorAndIndex() {
        let result = SelectionService.range(anchor: 3, to: 3, count: 10)

        #expect(result == [3])
    }

    @Test("range on an empty list returns an empty set")
    func rangeOnEmptyListIsEmpty() {
        let result = SelectionService.range(anchor: 0, to: 3, count: 0)

        #expect(result == [])
    }

    // MARK: - firstIndex / lastIndex (KN-04: Cmd+Arrow jump to first/last)

    @Test("firstIndex returns 0 for a non-empty list")
    func firstIndexOnNonEmptyList() {
        #expect(SelectionService.firstIndex(count: 7) == 0)
    }

    @Test("lastIndex returns count - 1 for a non-empty list")
    func lastIndexOnNonEmptyList() {
        #expect(SelectionService.lastIndex(count: 7) == 6)
    }

    @Test("firstIndex returns nil for an empty list")
    func firstIndexOnEmptyListIsNil() {
        #expect(SelectionService.firstIndex(count: 0) == nil)
    }

    @Test("lastIndex returns nil for an empty list")
    func lastIndexOnEmptyListIsNil() {
        #expect(SelectionService.lastIndex(count: 0) == nil)
    }

    // MARK: - invert

    @Test("invert flips selected and unselected indices")
    func invertFlipsSelection() {
        let result = SelectionService.invert([1, 3], count: 5)

        #expect(result == [0, 2, 4])
    }

    @Test("invert of a fully-selected list returns an empty set")
    func invertOfFullSelectionIsEmpty() {
        let result = SelectionService.invert([0, 1, 2], count: 3)

        #expect(result == [])
    }

    @Test("invert of an empty selection selects everything")
    func invertOfEmptySelectionSelectsAll() {
        let result = SelectionService.invert([], count: 3)

        #expect(result == [0, 1, 2])
    }

    @Test("invert on an empty list returns an empty set")
    func invertOnEmptyListIsEmpty() {
        let result = SelectionService.invert([], count: 0)

        #expect(result == [])
    }

    // MARK: - toggleAndAdvance (KN-06: Insert to toggle selection and move down)

    @Test("toggleAndAdvance selects the index and advances the cursor by one")
    func toggleAndAdvanceSelectsAndMovesDown() {
        let result = SelectionService.toggleAndAdvance([], index: 1, count: 5)

        #expect(result.selected == [1])
        #expect(result.nextIndex == 2)
    }

    @Test("toggleAndAdvance deselects the index and still advances the cursor")
    func toggleAndAdvanceDeselectsAndMovesDown() {
        let result = SelectionService.toggleAndAdvance([1], index: 1, count: 5)

        #expect(result.selected == [])
        #expect(result.nextIndex == 2)
    }

    @Test("toggleAndAdvance clamps the next index at the last entry")
    func toggleAndAdvanceClampsAtLastIndex() {
        let result = SelectionService.toggleAndAdvance([], index: 4, count: 5)

        #expect(result.selected == [4])
        #expect(result.nextIndex == 4)
    }

    @Test("toggleAndAdvance on an empty list leaves selection unchanged with a nil next index")
    func toggleAndAdvanceOnEmptyList() {
        let result = SelectionService.toggleAndAdvance([], index: 0, count: 0)

        #expect(result.selected == [])
        #expect(result.nextIndex == nil)
    }
}

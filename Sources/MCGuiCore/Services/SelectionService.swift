import Foundation

/// Pure, stateless multi-selection logic over a panel's `Set<Int>` of selected indices.
///
/// Operates on index sets rather than `FileEntry` values so it stays agnostic of how a
/// panel represents its rows; callers (panel view models) own the actual `PanelState`.
public enum SelectionService {

    /// Toggles membership of `index` in `selected`. Out-of-bounds indices (including any
    /// index when `count == 0`) are a no-op.
    public static func toggle(_ selected: Set<Int>, index: Int, count: Int) -> Set<Int> {
        guard index >= 0, index < count else { return selected }

        var result = selected
        if result.contains(index) {
            result.remove(index)
        } else {
            result.insert(index)
        }
        return result
    }

    /// Produces a contiguous range selection between `anchor` and `index` (inclusive),
    /// as used by Shift+Arrow range selection. Indices are clamped to the valid
    /// `0..<count` bounds; returns an empty set when `count == 0`.
    public static func range(anchor: Int, to index: Int, count: Int) -> Set<Int> {
        guard count > 0 else { return [] }

        let clampedAnchor = min(max(anchor, 0), count - 1)
        let clampedIndex = min(max(index, 0), count - 1)
        let lower = min(clampedAnchor, clampedIndex)
        let upper = max(clampedAnchor, clampedIndex)
        return Set(lower...upper)
    }

    /// The index of the first entry, for Cmd+Arrow jump-to-first. `nil` when the list is empty.
    public static func firstIndex(count: Int) -> Int? {
        count > 0 ? 0 : nil
    }

    /// The index of the last entry, for Cmd+Arrow jump-to-last. `nil` when the list is empty.
    public static func lastIndex(count: Int) -> Int? {
        count > 0 ? count - 1 : nil
    }

    /// Inverts selection across all `0..<count` entries: selected indices become
    /// unselected and vice versa.
    public static func invert(_ selected: Set<Int>, count: Int) -> Set<Int> {
        guard count > 0 else { return [] }

        var result: Set<Int> = []
        for i in 0..<count where !selected.contains(i) {
            result.insert(i)
        }
        return result
    }

    /// Toggles `index` (Insert key) and returns the next index to move the cursor to
    /// (index + 1, clamped to the last valid index). Returns the unchanged selection and
    /// a `nil` next index when `count == 0`.
    public static func toggleAndAdvance(_ selected: Set<Int>, index: Int, count: Int) -> (selected: Set<Int>, nextIndex: Int?) {
        guard count > 0 else { return (selected, nil) }

        let newSelection = toggle(selected, index: index, count: count)
        let next = min(index + 1, count - 1)
        return (newSelection, next)
    }
}

import Foundation

public enum SelectionService {

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

    public static func range(anchor: Int, to index: Int, count: Int) -> Set<Int> {
        guard count > 0 else { return [] }

        let clampedAnchor = min(max(anchor, 0), count - 1)
        let clampedIndex = min(max(index, 0), count - 1)
        let lower = min(clampedAnchor, clampedIndex)
        let upper = max(clampedAnchor, clampedIndex)
        return Set(lower...upper)
    }

    public static func firstIndex(count: Int) -> Int? {
        count > 0 ? 0 : nil
    }

    public static func lastIndex(count: Int) -> Int? {
        count > 0 ? count - 1 : nil
    }

    public static func invert(_ selected: Set<Int>, count: Int) -> Set<Int> {
        guard count > 0 else { return [] }

        var result: Set<Int> = []
        for i in 0..<count where !selected.contains(i) {
            result.insert(i)
        }
        return result
    }

    public static func toggleAndAdvance(_ selected: Set<Int>, index: Int, count: Int) -> (selected: Set<Int>, nextIndex: Int?) {
        guard count > 0 else { return (selected, nil) }

        let newSelection = toggle(selected, index: index, count: count)
        let next = min(index + 1, count - 1)
        return (newSelection, next)
    }
}

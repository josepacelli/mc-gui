import Foundation
import MCGuiCore

public enum PanelCommands {

    private static func index(of id: FileEntry.ID?, in entries: [FileEntry]) -> Int? {
        guard let id else { return nil }
        return entries.firstIndex(where: { $0.id == id })
    }

    public static func moveCursor(_ id: FileEntry.ID?, delta: Int, entries: [FileEntry]) -> FileEntry.ID? {
        guard !entries.isEmpty else { return nil }
        let current = index(of: id, in: entries) ?? (delta > 0 ? -1 : 0)
        let next = min(max(current + delta, 0), entries.count - 1)
        return entries[next].id
    }

    public static func extendSelection(
        anchor: FileEntry.ID?,
        cursor: FileEntry.ID?,
        delta: Int,
        entries: [FileEntry]
    ) -> (selection: Set<FileEntry.ID>, cursor: FileEntry.ID?) {
        guard !entries.isEmpty else { return ([], nil) }
        let anchorIndex = index(of: anchor, in: entries) ?? 0
        let cursorIndex = index(of: cursor, in: entries) ?? anchorIndex
        let nextCursorIndex = min(max(cursorIndex + delta, 0), entries.count - 1)
        let rangeIndices = SelectionService.range(anchor: anchorIndex, to: nextCursorIndex, count: entries.count)
        let selection = Set(rangeIndices.map { entries[$0].id })
        return (selection, entries[nextCursorIndex].id)
    }

    public static func jump(toFirst: Bool, entries: [FileEntry]) -> FileEntry.ID? {
        let target = toFirst
            ? SelectionService.firstIndex(count: entries.count)
            : SelectionService.lastIndex(count: entries.count)
        guard let target else { return nil }
        return entries[target].id
    }

    public static func toggleSelection(_ selection: Set<FileEntry.ID>, id: FileEntry.ID?, entries: [FileEntry]) -> Set<FileEntry.ID> {
        guard let targetIndex = index(of: id, in: entries) else { return selection }
        let indices = Set(selection.compactMap { index(of: $0, in: entries) })
        let toggled = SelectionService.toggle(indices, index: targetIndex, count: entries.count)
        return Set(toggled.map { entries[$0].id })
    }

    public static func toggleAndAdvance(
        _ selection: Set<FileEntry.ID>,
        id: FileEntry.ID?,
        entries: [FileEntry]
    ) -> (selection: Set<FileEntry.ID>, nextCursor: FileEntry.ID?) {
        guard let targetIndex = index(of: id, in: entries) else { return (selection, nil) }
        let indices = Set(selection.compactMap { index(of: $0, in: entries) })
        let result = SelectionService.toggleAndAdvance(indices, index: targetIndex, count: entries.count)
        let newSelection = Set(result.selected.map { entries[$0].id })
        let nextCursor = result.nextIndex.map { entries[$0].id }
        return (newSelection, nextCursor)
    }

    public static func selectAll(entries: [FileEntry]) -> Set<FileEntry.ID> {
        Set(entries.map(\.id))
    }

    public static func deselectAll() -> Set<FileEntry.ID> {
        []
    }

    public static func invertSelection(_ selection: Set<FileEntry.ID>, entries: [FileEntry]) -> Set<FileEntry.ID> {
        let indices = Set(selection.compactMap { index(of: $0, in: entries) })
        let inverted = SelectionService.invert(indices, count: entries.count)
        return Set(inverted.map { entries[$0].id })
    }
}

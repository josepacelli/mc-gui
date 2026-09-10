import Foundation
import MCGuiCore

/// Panel-specific keyboard navigation (KN-01..KN-06): translates key-driven navigation
/// requests into `SelectionService` calls, bridging between the `Set<FileEntry.ID>`
/// selection `PanelView` holds and the `Set<Int>` index space `SelectionService` (T9)
/// operates on. `SelectionService` itself already carries the actual selection semantics
/// (range/toggle/jump/invert) and is unit-tested in isolation - these functions are the
/// wiring layer on top of it.
///
// SPEC_DEVIATION (T45): `PanelView`'s selection state (`@State private var selection:
// Set<UUID>`) lives in `PanelView.swift`, which this task's `Where` field does not list -
// only `Sources/MCGuiUI/Commands/PanelCommands.swift`. These are therefore self-contained
// pure functions a caller applies against its own selection/cursor state; physically
// hooking them into `PanelView`'s `.onKeyPress` (arrow/Shift+Arrow/Cmd+Arrow/Space/Insert
// key detection) is wiring left for a future task, mirroring T38/T43's cross-target-wiring
// deferral for F3/F4. KN-01 (Tab switches active panel) needs no new logic here -
// `MainWindowViewModel.switchActivePanel()` (T18) already implements and unit-tests it;
// wiring a Tab key press to that existing call is likewise deferred alongside the rest.
public enum PanelCommands {

    private static func index(of id: FileEntry.ID?, in entries: [FileEntry]) -> Int? {
        guard let id else { return nil }
        return entries.firstIndex(where: { $0.id == id })
    }

    /// Moves the keyboard cursor one entry up/down (a plain arrow press, KN-02) without
    /// changing the selection. `delta` is -1 (up) or +1 (down). With no current cursor,
    /// starts at the first entry for a downward move (or the first entry for an upward
    /// move, since there is nothing before it). `nil` when `entries` is empty; otherwise
    /// clamped to `entries`' bounds.
    public static func moveCursor(_ id: FileEntry.ID?, delta: Int, entries: [FileEntry]) -> FileEntry.ID? {
        guard !entries.isEmpty else { return nil }
        let current = index(of: id, in: entries) ?? (delta > 0 ? -1 : 0)
        let next = min(max(current + delta, 0), entries.count - 1)
        return entries[next].id
    }

    /// Extends the selection from `anchor` through the entry `delta` away from `cursor`
    /// (Shift+Arrow, KN-03), via `SelectionService.range`. Returns the new selection and
    /// the new cursor id (the range's moving end). Empty selection and `nil` cursor when
    /// `entries` is empty.
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

    /// Jumps the cursor to the first or last entry (Cmd+Arrow, KN-04), via
    /// `SelectionService.firstIndex`/`lastIndex`. `nil` when `entries` is empty.
    public static func jump(toFirst: Bool, entries: [FileEntry]) -> FileEntry.ID? {
        let target = toFirst
            ? SelectionService.firstIndex(count: entries.count)
            : SelectionService.lastIndex(count: entries.count)
        guard let target else { return nil }
        return entries[target].id
    }

    /// Toggles `id`'s membership in `selection` (Space, KN-05), via
    /// `SelectionService.toggle`. Unchanged when `id` is `nil` or not found in `entries`.
    public static func toggleSelection(_ selection: Set<FileEntry.ID>, id: FileEntry.ID?, entries: [FileEntry]) -> Set<FileEntry.ID> {
        guard let targetIndex = index(of: id, in: entries) else { return selection }
        let indices = Set(selection.compactMap { index(of: $0, in: entries) })
        let toggled = SelectionService.toggle(indices, index: targetIndex, count: entries.count)
        return Set(toggled.map { entries[$0].id })
    }

    /// Toggles `id` and advances the cursor to the next entry (Insert, KN-06), via
    /// `SelectionService.toggleAndAdvance`. Unchanged selection and `nil` next cursor when
    /// `id` is `nil`/not found or `entries` is empty.
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

    /// Selects every entry ("*"). Bugfix: "*" used to invert the selection (classic mc's
    /// actual behavior), but that deselected whatever was already marked instead of adding
    /// to it - per user report/request, "*" now always selects everything, regardless of
    /// what was selected before.
    public static func selectAll(entries: [FileEntry]) -> Set<FileEntry.ID> {
        Set(entries.map(\.id))
    }

    /// Clears the whole selection ("-", a secondary key for keyboards without a working
    /// physical Delete/Insert - see `deselectAllEntries` in `PanelView`).
    public static func deselectAll() -> Set<FileEntry.ID> {
        []
    }
}

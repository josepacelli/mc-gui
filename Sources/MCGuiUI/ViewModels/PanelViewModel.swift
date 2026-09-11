import Foundation
import Observation
import MCGuiCore

/// Directory-listing state for one file panel: loads entries via an injected
/// `FileSystemService`, sorts them by column, and filters hidden files.
///
/// Selection (`SelectionService`) and keyboard-driven navigation are wired separately in
/// `PanelCommands` (Phase 9) - this ViewModel only owns what's listed, how it's loaded,
/// sorted, and filtered.
@MainActor
@Observable
public final class PanelViewModel {
    // SPEC_DEVIATION (T33): exposed as `public` (was `private`) so `PanelView` can wire
    // F5/F6/F7/F8 file operations (FO-01, FO-02, FO-10, FO-12) directly against the same
    // `FileSystemService` instance this panel already loads through - no new dependency,
    // just visibility, since MCGuiUI has no other way to obtain a `FileSystemService`
    // (MCGuiUI does not depend on MCGuiMacOS, so it cannot construct one itself).
    public let fileSystemService: FileSystemService
    private var rawEntries: [FileEntry] = []

    public private(set) var currentPath: URL
    public private(set) var entries: [FileEntry] = []
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?
    // FS-11..FS-13: in-memory back/forward history (disk persistence is the separate
    // PathHistoryStore/PathHistoryStoreImpl, not wired here).
    public private(set) var history = PanelPathHistory()

    public var canGoBack: Bool { !history.past.isEmpty }
    public var canGoForward: Bool { !history.future.isEmpty }

    public var sortColumn: PanelSortColumn = .name {
        didSet { applyFilterAndSort() }
    }

    public var sortAscending: Bool = true {
        didSet { applyFilterAndSort() }
    }

    public var showHidden: Bool = false {
        didSet { applyFilterAndSort() }
    }

    /// Live filename filter text (SF-01): case-insensitive, substring-anywhere match
    /// against `FileEntry.name` (SF-02, SF-03). Empty means no filtering.
    public var filterText: String = "" {
        didSet { applyFilterAndSort() }
    }

    public init(fileSystemService: FileSystemService, initialPath: URL) {
        self.fileSystemService = fileSystemService
        self.currentPath = initialPath
    }

    /// Loads `path` (or the current path when `path` is `nil`) via the injected
    /// `FileSystemService`. Also used for directory navigation (FS-04 enter directory,
    /// FS-05 navigate to parent) - callers simply pass the target directory's URL. A real
    /// navigation (`path` differs from `currentPath`) records `currentPath` into `history`
    /// (FS-11), discarding any forward history - the classic browser-history rule, since
    /// forward entries no longer follow from the new current path. Reloading the same
    /// path (refresh, `path == nil`) does not touch history.
    ///
    /// On success, replaces `entries` and clears any previous error. On failure, leaves
    /// `currentPath`/`entries`/`history` unchanged and sets `errorMessage` to the failure
    /// reason (FS-08).
    public func load(_ path: URL? = nil) async {
        await load(path, historyOverride: nil)
    }

    /// FS-12: navigates to the previous entry in `history.past`, pushing `currentPath`
    /// onto `future`. A no-op when there is nothing to go back to.
    public func goBack() async {
        guard let (target, newHistory) = PathHistoryManager.back(from: currentPath, history: history) else { return }
        await load(target, historyOverride: newHistory)
    }

    /// FS-13: navigates to the next entry in `history.future`, pushing `currentPath` onto
    /// `past`. A no-op when there is nothing to go forward to.
    public func goForward() async {
        guard let (target, newHistory) = PathHistoryManager.forward(from: currentPath, history: history) else { return }
        await load(target, historyOverride: newHistory)
    }

    /// Shared implementation for `load`/`goBack`/`goForward`: `historyOverride`, when
    /// given, replaces `history` outright on success (back/forward already computed the
    /// correct past/future via `PathHistoryManager`); `nil` means a normal navigation,
    /// which instead appends to `history` via `PathHistoryManager.navigate` when `target`
    /// differs from `currentPath`. Either way, `history` only changes once the load
    /// actually succeeds - a failed navigation must not desync history from `currentPath`.
    private func load(_ path: URL?, historyOverride: PanelPathHistory?) async {
        let target = path ?? currentPath
        isLoading = true
        defer { isLoading = false }

        do {
            let loaded = try await fileSystemService.listDirectory(target)
            if let historyOverride {
                history = historyOverride
            } else if target != currentPath {
                history = PathHistoryManager.navigate(to: target, from: currentPath, history: history)
            }
            currentPath = target
            errorMessage = nil
            rawEntries = loaded
            applyFilterAndSort()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Clears the live filename filter (SF-04: Escape), restoring the full (hidden-filtered,
    /// sorted) entries list.
    public func clearFilter() {
        filterText = ""
    }

    private func applyFilterAndSort() {
        var visible = showHidden ? rawEntries : rawEntries.filter { !$0.isHidden }
        if !filterText.isEmpty {
            visible = visible.filter { $0.name.localizedCaseInsensitiveContains(filterText) }
        }
        entries = Self.sorted(visible, by: sortColumn, ascending: sortAscending)
    }

    /// Orders `entries` by `column`. Ties (equal `type`) fall back to a name comparison
    /// so the order is deterministic. `name`/`type` comparisons are case-insensitive,
    /// locale-aware (`localizedStandardCompare`).
    private static func sorted(_ entries: [FileEntry], by column: PanelSortColumn, ascending: Bool) -> [FileEntry] {
        let isOrderedBefore: (FileEntry, FileEntry) -> Bool
        switch column {
        case .name:
            isOrderedBefore = { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .size:
            isOrderedBefore = { $0.size < $1.size }
        case .date:
            isOrderedBefore = { $0.modificationDate < $1.modificationDate }
        case .type:
            isOrderedBefore = {
                $0.type.rawValue == $1.type.rawValue
                    ? $0.name.localizedStandardCompare($1.name) == .orderedAscending
                    : $0.type.rawValue < $1.type.rawValue
            }
        }

        let ascendingOrder = entries.sorted(by: isOrderedBefore)
        return ascending ? ascendingOrder : Array(ascendingOrder.reversed())
    }
}

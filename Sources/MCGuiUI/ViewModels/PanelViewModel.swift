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
    private let fileSystemService: FileSystemService
    private var rawEntries: [FileEntry] = []

    public private(set) var currentPath: URL
    public private(set) var entries: [FileEntry] = []
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    public var sortColumn: PanelSortColumn = .name {
        didSet { applyFilterAndSort() }
    }

    public var sortAscending: Bool = true {
        didSet { applyFilterAndSort() }
    }

    public var showHidden: Bool = false {
        didSet { applyFilterAndSort() }
    }

    public init(fileSystemService: FileSystemService, initialPath: URL) {
        self.fileSystemService = fileSystemService
        self.currentPath = initialPath
    }

    /// Loads `path` (or the current path when `path` is `nil`) via the injected
    /// `FileSystemService`. Also used for directory navigation (FS-04 enter directory,
    /// FS-05 navigate to parent) - callers simply pass the target directory's URL.
    ///
    /// On success, replaces `entries` and clears any previous error. On failure, leaves
    /// `currentPath`/`entries` unchanged and sets `errorMessage` to the failure reason
    /// (FS-08).
    public func load(_ path: URL? = nil) async {
        let target = path ?? currentPath
        isLoading = true
        defer { isLoading = false }

        do {
            let loaded = try await fileSystemService.listDirectory(target)
            currentPath = target
            errorMessage = nil
            rawEntries = loaded
            applyFilterAndSort()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyFilterAndSort() {
        let visible = showHidden ? rawEntries : rawEntries.filter { !$0.isHidden }
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

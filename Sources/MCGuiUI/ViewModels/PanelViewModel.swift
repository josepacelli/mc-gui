import Foundation
import Observation
import MCGuiCore

@MainActor
@Observable
public final class PanelViewModel {
    public let fileSystemService: FileSystemService
    public let instanceID = UUID()
    private var rawEntries: [FileEntry] = []

    public private(set) var currentPath: URL
    public private(set) var entries: [FileEntry] = []
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?
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

    public var filterText: String = "" {
        didSet { applyFilterAndSort() }
    }

    public init(fileSystemService: FileSystemService, initialPath: URL) {
        self.fileSystemService = fileSystemService
        self.currentPath = initialPath
    }

    public func load(_ path: URL? = nil) async {
        await load(path, historyOverride: nil)
    }

    public func goBack() async {
        guard let (target, newHistory) = PathHistoryManager.back(from: currentPath, history: history) else { return }
        await load(target, historyOverride: newHistory)
    }

    public func goForward() async {
        guard let (target, newHistory) = PathHistoryManager.forward(from: currentPath, history: history) else { return }
        await load(target, historyOverride: newHistory)
    }

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

import Foundation

/// The column a panel's file list is currently sorted by.
public enum PanelSortColumn: String, Codable, CaseIterable {
    case name, size, date, type
}

/// Back/forward navigation history for a single panel.
public struct PanelPathHistory: Codable, Hashable {
    public var past: [URL]
    public var future: [URL]

    public init(past: [URL] = [], future: [URL] = []) {
        self.past = past
        self.future = future
    }
}

/// The full navigable state of one file panel.
public struct PanelState: Codable {
    public var currentPath: URL
    public var entries: [FileEntry]
    public var selectedIndices: Set<Int>
    public var sortColumn: PanelSortColumn
    public var sortAscending: Bool
    public var showHidden: Bool
    public var history: PanelPathHistory

    public init(
        currentPath: URL,
        entries: [FileEntry] = [],
        selectedIndices: Set<Int> = [],
        sortColumn: PanelSortColumn = .name,
        sortAscending: Bool = true,
        showHidden: Bool = false,
        history: PanelPathHistory = PanelPathHistory()
    ) {
        self.currentPath = currentPath
        self.entries = entries
        self.selectedIndices = selectedIndices
        self.sortColumn = sortColumn
        self.sortAscending = sortAscending
        self.showHidden = showHidden
        self.history = history
    }
}

import Foundation
import MCGuiCore

/// `PathHistoryStore` implementation: persists each panel's `PanelPathHistory` as JSON
/// under `~/Library/Application Support/MCGui/`, one file per `PanelSide` (PH-01/PH-02),
/// capped at 100 entries total on save (PH-03), with corrupt-file recovery to an empty
/// history (PH-04).
public final class PathHistoryStoreImpl: PathHistoryStore {
    private let directory: URL
    private let maxEntries: Int
    private let fileManager: FileManager

    public init(
        directory: URL? = nil,
        maxEntries: Int = 100,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.directory = directory ?? Self.defaultDirectory(fileManager: fileManager)
        self.maxEntries = maxEntries
    }

    private static func defaultDirectory(fileManager: FileManager) -> URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return appSupport.appendingPathComponent("MCGui", isDirectory: true)
    }

    private func fileURL(for panel: PanelSide) -> URL {
        directory.appendingPathComponent("history-\(panel.rawValue).json")
    }

    public func save(_ history: PanelPathHistory, for panel: PanelSide) async throws {
        let capped = Self.cappingToTotal(history, maxEntries: maxEntries)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(capped)
        try data.write(to: fileURL(for: panel), options: .atomic)
    }

    public func load(for panel: PanelSide) async throws -> PanelPathHistory {
        let url = fileURL(for: panel)
        guard fileManager.fileExists(atPath: url.path) else {
            return PanelPathHistory()
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(PanelPathHistory.self, from: data)
        } catch {
            return PanelPathHistory()
        }
    }

    /// Trims `past`/`future` so their combined count never exceeds `maxEntries`,
    /// dropping the oldest `past` entries first (the unbounded-growth side during normal
    /// browsing), then the oldest `future` entries if still over the cap.
    private static func cappingToTotal(_ history: PanelPathHistory, maxEntries: Int) -> PanelPathHistory {
        var past = history.past
        var future = history.future

        while past.count + future.count > maxEntries {
            if !past.isEmpty {
                past.removeFirst()
            } else {
                future.removeFirst()
            }
        }

        return PanelPathHistory(past: past, future: future)
    }
}

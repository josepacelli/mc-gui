import Foundation

/// A bookmarked directory (BM-01..04). No C# equivalent exists - this is a new feature.
public struct Bookmark: Identifiable, Hashable, Codable {
    public let id: UUID
    public let name: String
    public let path: URL

    public init(id: UUID = UUID(), name: String, path: URL) {
        self.id = id
        self.name = name
        self.path = path
    }
}

/// JSON-persisted bookmark store (add/remove/list), mirroring `PathHistoryStoreImpl`'s
/// persistence pattern: bookmarks live at `~/Library/Application Support/MCGui/
/// bookmarks.json` (BM-03), with corrupt-file recovery to an empty list.
public final class BookmarkStore {
    private let fileURL: URL
    private let fileManager: FileManager

    public init(directory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let resolvedDirectory = directory ?? Self.defaultDirectory(fileManager: fileManager)
        self.fileURL = resolvedDirectory.appendingPathComponent("bookmarks.json")
    }

    private static func defaultDirectory(fileManager: FileManager) -> URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return appSupport.appendingPathComponent("MCGui", isDirectory: true)
    }

    /// Lists all bookmarks (BM-02 data, BM-03 persistence). An empty list when no file
    /// exists yet, or when the file is corrupted (BM-03's persistence contract mirrors
    /// `PathHistoryStoreImpl`'s PH-04 corrupt-file recovery).
    public func list() async throws -> [Bookmark] {
        guard fileManager.fileExists(atPath: fileURL.path) else { return [] }

        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([Bookmark].self, from: data)
        } catch {
            return []
        }
    }

    /// Adds `bookmark` and persists the updated list (BM-01).
    public func add(_ bookmark: Bookmark) async throws {
        var bookmarks = try await list()
        bookmarks.append(bookmark)
        try await save(bookmarks)
    }

    /// Removes the bookmark with `id`, if present, and persists the updated list (BM-04).
    public func remove(id: UUID) async throws {
        var bookmarks = try await list()
        bookmarks.removeAll { $0.id == id }
        try await save(bookmarks)
    }

    private func save(_ bookmarks: [Bookmark]) async throws {
        try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(bookmarks)
        try data.write(to: fileURL, options: .atomic)
    }
}

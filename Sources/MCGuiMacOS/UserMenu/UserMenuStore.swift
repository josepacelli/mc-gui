import Foundation

/// A user-defined menu item (F2): a label and a shell command template using `%f`/`%d`/
/// `%D` macros (see `UserMenuRunner`). Scoped down from the original mc's 9-macro,
/// submenu-capable `.mnu`-format menu to a flat list of shell commands - real utility,
/// contained scope, mirroring `Bookmark`'s own simplification.
public struct UserMenuItem: Identifiable, Hashable, Codable {
    public let id: UUID
    public let label: String
    public let command: String

    public init(id: UUID = UUID(), label: String, command: String) {
        self.id = id
        self.label = label
        self.command = command
    }
}

/// JSON-persisted user-menu store (add/remove/list), mirroring `BookmarkStore`'s own
/// persistence pattern: items live at `~/Library/Application Support/MCGui/
/// user-menu.json`, with corrupt-file recovery to an empty list.
public final class UserMenuStore {
    private let fileURL: URL
    private let fileManager: FileManager

    public init(directory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let resolvedDirectory = directory ?? Self.defaultDirectory(fileManager: fileManager)
        self.fileURL = resolvedDirectory.appendingPathComponent("user-menu.json")
    }

    private static func defaultDirectory(fileManager: FileManager) -> URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return appSupport.appendingPathComponent("MCGui", isDirectory: true)
    }

    /// Lists all items. An empty list when no file exists yet, or when the file is
    /// corrupted.
    public func list() async throws -> [UserMenuItem] {
        guard fileManager.fileExists(atPath: fileURL.path) else { return [] }

        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([UserMenuItem].self, from: data)
        } catch {
            return []
        }
    }

    /// Adds `item` and persists the updated list.
    public func add(_ item: UserMenuItem) async throws {
        var items = try await list()
        items.append(item)
        try await save(items)
    }

    /// Removes the item with `id`, if present, and persists the updated list.
    public func remove(id: UUID) async throws {
        var items = try await list()
        items.removeAll { $0.id == id }
        try await save(items)
    }

    private func save(_ items: [UserMenuItem]) async throws {
        try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(items)
        try data.write(to: fileURL, options: .atomic)
    }
}

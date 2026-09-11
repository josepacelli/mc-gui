import Foundation

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

    public func list() async throws -> [UserMenuItem] {
        guard fileManager.fileExists(atPath: fileURL.path) else { return [] }

        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([UserMenuItem].self, from: data)
        } catch {
            return []
        }
    }

    public func add(_ item: UserMenuItem) async throws {
        var items = try await list()
        items.append(item)
        try await save(items)
    }

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

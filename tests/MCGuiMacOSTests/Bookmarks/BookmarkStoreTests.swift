import Foundation
import Testing
@testable import MCGuiMacOS

@Suite("BookmarkStore")
struct BookmarkStoreTests {

    private func makeTempDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("bookmarkstore-\(UUID().uuidString)", isDirectory: true)
    }


    @Test("add persists a bookmark that a fresh store instance can reload")
    func addPersistsAndReloads() async throws {
        let dir = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let bookmark = Bookmark(name: "Projects", path: URL(fileURLWithPath: "/tmp/projects"))
        let store = BookmarkStore(directory: dir)

        try await store.add(bookmark)

        let reloaded = try await BookmarkStore(directory: dir).list()
        #expect(reloaded == [bookmark])
    }

    @Test("adding multiple bookmarks accumulates them in list order")
    func addAccumulatesMultipleBookmarks() async throws {
        let dir = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let first = Bookmark(name: "Projects", path: URL(fileURLWithPath: "/tmp/projects"))
        let second = Bookmark(name: "Downloads", path: URL(fileURLWithPath: "/tmp/downloads"))
        let store = BookmarkStore(directory: dir)

        try await store.add(first)
        try await store.add(second)

        let list = try await store.list()
        #expect(list == [first, second])
    }


    @Test("remove deletes the bookmark with the given id and persists the change")
    func removeDeletesBookmarkAndPersists() async throws {
        let dir = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let toKeep = Bookmark(name: "Projects", path: URL(fileURLWithPath: "/tmp/projects"))
        let toRemove = Bookmark(name: "Downloads", path: URL(fileURLWithPath: "/tmp/downloads"))
        let store = BookmarkStore(directory: dir)
        try await store.add(toKeep)
        try await store.add(toRemove)

        try await store.remove(id: toRemove.id)

        let list = try await BookmarkStore(directory: dir).list()
        #expect(list == [toKeep])
    }

    @Test("remove with an id that is not present is a no-op")
    func removeWithUnknownIdIsNoOp() async throws {
        let dir = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let bookmark = Bookmark(name: "Projects", path: URL(fileURLWithPath: "/tmp/projects"))
        let store = BookmarkStore(directory: dir)
        try await store.add(bookmark)

        try await store.remove(id: UUID())

        #expect(try await store.list() == [bookmark])
    }


    @Test("list recovers to an empty array when the JSON file is corrupted")
    func listRecoversFromCorruptedJSON() async throws {
        let dir = makeTempDirectory()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try Data("{ not valid json".utf8).write(to: dir.appendingPathComponent("bookmarks.json"))

        let list = try await BookmarkStore(directory: dir).list()

        #expect(list.isEmpty)
    }

    @Test("list recovers to an empty array when the file is missing")
    func listRecoversFromMissingFile() async throws {
        let dir = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let list = try await BookmarkStore(directory: dir).list()

        #expect(list.isEmpty)
    }
}

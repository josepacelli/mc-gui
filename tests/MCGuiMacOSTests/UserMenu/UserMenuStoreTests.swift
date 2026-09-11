import Foundation
import Testing
@testable import MCGuiMacOS

@Suite("UserMenuStore")
struct UserMenuStoreTests {

    private func makeTempDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("usermenustore-\(UUID().uuidString)", isDirectory: true)
    }


    @Test("add persists an item that a fresh store instance can reload")
    func addPersistsAndReloads() async throws {
        let dir = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let item = UserMenuItem(label: "Git Status", command: "git status %d")
        let store = UserMenuStore(directory: dir)

        try await store.add(item)

        let reloaded = try await UserMenuStore(directory: dir).list()
        #expect(reloaded == [item])
    }

    @Test("adding multiple items accumulates them in list order")
    func addAccumulatesMultipleItems() async throws {
        let dir = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let first = UserMenuItem(label: "Git Status", command: "git status %d")
        let second = UserMenuItem(label: "Open in Finder", command: "open %d")
        let store = UserMenuStore(directory: dir)

        try await store.add(first)
        try await store.add(second)

        let list = try await store.list()
        #expect(list == [first, second])
    }


    @Test("remove deletes the item with the given id and persists the change")
    func removeDeletesItemAndPersists() async throws {
        let dir = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let toKeep = UserMenuItem(label: "Git Status", command: "git status %d")
        let toRemove = UserMenuItem(label: "Open in Finder", command: "open %d")
        let store = UserMenuStore(directory: dir)
        try await store.add(toKeep)
        try await store.add(toRemove)

        try await store.remove(id: toRemove.id)

        let list = try await UserMenuStore(directory: dir).list()
        #expect(list == [toKeep])
    }

    @Test("remove with an id that is not present is a no-op")
    func removeWithUnknownIdIsNoOp() async throws {
        let dir = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let item = UserMenuItem(label: "Git Status", command: "git status %d")
        let store = UserMenuStore(directory: dir)
        try await store.add(item)

        try await store.remove(id: UUID())

        #expect(try await store.list() == [item])
    }


    @Test("list recovers to an empty array when the JSON file is corrupted")
    func listRecoversFromCorruptedJSON() async throws {
        let dir = makeTempDirectory()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try Data("{ not valid json".utf8).write(to: dir.appendingPathComponent("user-menu.json"))

        let list = try await UserMenuStore(directory: dir).list()

        #expect(list.isEmpty)
    }

    @Test("list recovers to an empty array when the file is missing")
    func listRecoversFromMissingFile() async throws {
        let dir = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let list = try await UserMenuStore(directory: dir).list()

        #expect(list.isEmpty)
    }
}

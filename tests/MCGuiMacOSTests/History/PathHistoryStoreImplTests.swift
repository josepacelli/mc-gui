import Foundation
import Testing
import MCGuiCore
@testable import MCGuiMacOS

@Suite("PathHistoryStoreImpl")
struct PathHistoryStoreImplTests {

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pathhistorystore-\(UUID().uuidString)", isDirectory: true)
        return url
    }

    // MARK: - save/load round-trip (PH-01/PH-02)

    @Test("save then load round-trips a PanelPathHistory through JSON on disk")
    func saveLoadRoundTrip() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let history = PanelPathHistory(
            past: [URL(fileURLWithPath: "/tmp/a"), URL(fileURLWithPath: "/tmp/b")],
            future: [URL(fileURLWithPath: "/tmp/c")]
        )
        let store = PathHistoryStoreImpl(directory: dir)

        try await store.save(history, for: .left)
        let loaded = try await store.load(for: .left)

        #expect(loaded == history)
    }

    @Test("history for left and right panels is stored independently")
    func leftAndRightHistoriesAreIndependent() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let leftHistory = PanelPathHistory(past: [URL(fileURLWithPath: "/tmp/left")], future: [])
        let rightHistory = PanelPathHistory(past: [URL(fileURLWithPath: "/tmp/right")], future: [])
        let store = PathHistoryStoreImpl(directory: dir)

        try await store.save(leftHistory, for: .left)
        try await store.save(rightHistory, for: .right)

        #expect(try await store.load(for: .left) == leftHistory)
        #expect(try await store.load(for: .right) == rightHistory)
    }

    // MARK: - corrupted / missing file recovery (PH-04)

    @Test("load recovers to an empty history when the JSON file is corrupted")
    func loadRecoversFromCorruptedJSON() async throws {
        let dir = try makeTempDirectory()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = PathHistoryStoreImpl(directory: dir)
        try Data("{ not valid json".utf8).write(to: dir.appendingPathComponent("history-left.json"))

        let loaded = try await store.load(for: .left)

        #expect(loaded == PanelPathHistory())
    }

    @Test("load recovers to an empty history when the file is missing")
    func loadRecoversFromMissingFile() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = PathHistoryStoreImpl(directory: dir)

        let loaded = try await store.load(for: .right)

        #expect(loaded == PanelPathHistory())
    }

    // MARK: - 100-entry cap (PH-03)

    @Test("save truncates history to at most 100 total entries, keeping the most recent")
    func saveTruncatesTo100Entries() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let past = (0..<150).map { URL(fileURLWithPath: "/tmp/entry-\($0)") }
        let history = PanelPathHistory(past: past, future: [])
        let store = PathHistoryStoreImpl(directory: dir)

        try await store.save(history, for: .left)
        let loaded = try await store.load(for: .left)

        #expect(loaded.past.count + loaded.future.count == 100)
        #expect(loaded.past.last == URL(fileURLWithPath: "/tmp/entry-149"))
        #expect(loaded.past.first == URL(fileURLWithPath: "/tmp/entry-50"))
    }
}

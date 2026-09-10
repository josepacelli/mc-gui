import Foundation
import Testing
import MCGuiCore
@testable import MCGuiMacOS

@Suite("EditorServiceImpl")
struct EditorServiceImplTests {

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("editorimpl-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: - load + save round-trip (ED-01, ED-04)

    @Test("open then save round-trips edited content back to disk as UTF-8")
    func loadAndSaveRoundTrip() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let fileURL = dir.appendingPathComponent("doc.txt")
        try Data("original content".utf8).write(to: fileURL)

        let service = EditorServiceImpl()
        var state = try await service.open(fileURL)
        #expect(state.content == "original content")
        #expect(state.encoding == "UTF-8")

        state.content = "edited content"
        try await service.save(state)

        let savedBytes = try Data(contentsOf: fileURL)
        #expect(String(data: savedBytes, encoding: .utf8) == "edited content")
    }

    // MARK: - non-UTF8 encoding detection (ED-01)

    @Test("open on a non-UTF8 file falls back to Latin-1 and reports that encoding")
    func openNonUtf8FileDetectsLatin1() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let fileURL = dir.appendingPathComponent("latin1.txt")
        // 0xE9 alone is not a valid UTF-8 lead byte for any continuation here, so this is
        // not valid UTF-8; in Latin-1 it decodes as "caf\u{e9}" ("café").
        let bytes = Data([0x63, 0x61, 0x66, 0xE9])
        try bytes.write(to: fileURL)

        let service = EditorServiceImpl()
        let state = try await service.open(fileURL)

        #expect(state.encoding == "Latin-1")
        #expect(state.content == "caf\u{e9}")
    }

    @Test("open strips a UTF-8 BOM and reports UTF-8 BOM as the encoding")
    func openStripsUtf8Bom() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let fileURL = dir.appendingPathComponent("bom.txt")
        var bytes = Data([0xEF, 0xBB, 0xBF])
        bytes.append(Data("hello".utf8))
        try bytes.write(to: fileURL)

        let service = EditorServiceImpl()
        let state = try await service.open(fileURL)

        #expect(state.encoding == "UTF-8 BOM")
        #expect(state.content == "hello")
    }

    // MARK: - save-to-read-only-path error

    @Test("save to a read-only file throws EditorServiceError.cannotWrite")
    func saveToReadOnlyFileThrowsCannotWrite() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let fileURL = dir.appendingPathComponent("readonly.txt")
        try Data("locked".utf8).write(to: fileURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: fileURL.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: fileURL.path) }

        let service = EditorServiceImpl()
        let state = EditorDocumentState(content: "new content", fileURL: fileURL, isDirty: true, encoding: "UTF-8")

        do {
            try await service.save(state)
            Issue.record("Expected EditorServiceError.cannotWrite to be thrown")
        } catch let error as EditorServiceError {
            #expect(error == .cannotWrite(fileURL))
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    // MARK: - open on a missing file

    @Test("open on a nonexistent file throws EditorServiceError.cannotRead")
    func openNonexistentFileThrowsCannotRead() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let missingURL = dir.appendingPathComponent("does-not-exist.txt")

        let service = EditorServiceImpl()

        do {
            _ = try await service.open(missingURL)
            Issue.record("Expected EditorServiceError.cannotRead to be thrown")
        } catch let error as EditorServiceError {
            #expect(error == .cannotRead(missingURL))
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    // MARK: - empty file

    @Test("open on an empty file returns empty content with UTF-8 encoding")
    func openEmptyFileReturnsEmptyContent() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let fileURL = dir.appendingPathComponent("empty.txt")
        try Data().write(to: fileURL)

        let service = EditorServiceImpl()
        let state = try await service.open(fileURL)

        #expect(state.content == "")
        #expect(state.encoding == "UTF-8")
    }
}

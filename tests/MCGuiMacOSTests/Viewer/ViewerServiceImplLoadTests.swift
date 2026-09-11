import Foundation
import Testing
import MCGuiCore
@testable import MCGuiMacOS

@Suite("ViewerServiceImpl - load (text/hex, chunked)")
struct ViewerServiceImplLoadTests {

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("viewerimpl-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }


    @Test("load on a small text file returns .text with the file's exact contents")
    func loadSmallTextFile() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let fileURL = dir.appendingPathComponent("small.txt")
        try Data("hello, viewer".utf8).write(to: fileURL)

        let service = ViewerServiceImpl()
        let content = try await service.load(fileURL)

        #expect(content == .text("hello, viewer"))
    }


    @Test("load on a multi-chunk file reads over multiple chunks and reassembles the exact content")
    func loadLargeFileReadsInChunksAndReassemblesContent() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let fileURL = dir.appendingPathComponent("large.txt")

        let line = String(repeating: "abcdefghij", count: 100) + "\n"
        let content = String(repeating: line, count: 3000)
        try Data(content.utf8).write(to: fileURL)

        final class ReadCounter { var count = 0 }
        let counter = ReadCounter()
        let service = ViewerServiceImpl(
            chunkSize: 64 * 1024,
            readChunk: { handle, size in
                counter.count += 1
                return handle.readData(ofLength: size)
            }
        )

        let loaded = try await service.load(fileURL)

        #expect(loaded == .text(content))
        #expect(counter.count > 1)
    }


    @Test("load on a nonexistent file throws ViewerServiceError.cannotRead")
    func loadNonexistentFileThrowsCannotRead() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let missingURL = dir.appendingPathComponent("does-not-exist.txt")

        let service = ViewerServiceImpl()

        do {
            _ = try await service.load(missingURL)
            Issue.record("Expected ViewerServiceError.cannotRead to be thrown")
        } catch let error as ViewerServiceError {
            #expect(error == .cannotRead(missingURL))
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }


    @Test("load on a file containing a NUL byte returns .hexData with the exact bytes")
    func loadBinaryFileReturnsHexData() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let fileURL = dir.appendingPathComponent("binary.dat")
        let bytes = Data([0x89, 0x50, 0x4E, 0x00, 0x0D, 0x0A])
        try bytes.write(to: fileURL)

        let service = ViewerServiceImpl()
        let content = try await service.load(fileURL)

        #expect(content == .hexData(bytes))
    }
}

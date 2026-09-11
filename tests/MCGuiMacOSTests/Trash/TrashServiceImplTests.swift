import Foundation
import Testing
import MCGuiCore
@testable import MCGuiMacOS

@Suite("TrashServiceImpl")
struct TrashServiceImplTests {

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("trashimpl-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @discardableResult
    private func writeFile(named name: String, in directory: URL) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try Data("content".utf8).write(to: url)
        return url
    }

    private func makeService(recordingInto trashedURLs: Recorder) -> TrashServiceImpl {
        TrashServiceImpl { url in
            var resultingItemURL: NSURL?
            try FileManager.default.trashItem(at: url, resultingItemURL: &resultingItemURL)
            if let resulting = resultingItemURL as URL? {
                trashedURLs.urls.append(resulting)
            }
            return resultingItemURL as URL?
        }
    }

    private func cleanUp(_ urls: [URL]) {
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }

    @Test("trash moves a single file to the macOS Trash, not a permanent delete")
    func trashSingleFileMovesToTrash() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let recorder = Recorder()
        defer { cleanUp(recorder.urls) }

        let fileURL = try writeFile(named: "a.txt", in: dir)

        let service = makeService(recordingInto: recorder)
        let result = try await service.trash([fileURL])

        #expect(result.success)
        #expect(result.processedCount == 1)
        #expect(result.failedItems == [])
        #expect(FileManager.default.fileExists(atPath: fileURL.path) == false)

        #expect(recorder.urls.count == 1)
        #expect(FileManager.default.fileExists(atPath: recorder.urls[0].path))
    }

    @Test("trash moves multiple files to the Trash")
    func trashMultipleFilesMovesAll() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let recorder = Recorder()
        defer { cleanUp(recorder.urls) }

        let firstURL = try writeFile(named: "a.txt", in: dir)
        let secondURL = try writeFile(named: "b.txt", in: dir)

        let service = makeService(recordingInto: recorder)
        let result = try await service.trash([firstURL, secondURL])

        #expect(result.success)
        #expect(result.processedCount == 2)
        #expect(result.failedItems == [])
        #expect(FileManager.default.fileExists(atPath: firstURL.path) == false)
        #expect(FileManager.default.fileExists(atPath: secondURL.path) == false)

        #expect(recorder.urls.count == 2)
        for trashedURL in recorder.urls {
            #expect(FileManager.default.fileExists(atPath: trashedURL.path))
        }
    }

    @Test("trash resolves an already-trashed-name collision without failing")
    func trashHandlesAlreadyTrashedNameCollision() async throws {
        let firstDir = try makeTempDirectory()
        let secondDir = try makeTempDirectory()
        defer {
            try? FileManager.default.removeItem(at: firstDir)
            try? FileManager.default.removeItem(at: secondDir)
        }
        let recorder = Recorder()
        defer { cleanUp(recorder.urls) }

        let sharedName = "dup.txt"
        let firstURL = try writeFile(named: sharedName, in: firstDir)
        let secondURL = try writeFile(named: sharedName, in: secondDir)

        let service = makeService(recordingInto: recorder)
        let firstResult = try await service.trash([firstURL])
        let secondResult = try await service.trash([secondURL])

        #expect(firstResult.success)
        #expect(firstResult.processedCount == 1)
        #expect(secondResult.success)
        #expect(secondResult.processedCount == 1)
        #expect(FileManager.default.fileExists(atPath: firstURL.path) == false)
        #expect(FileManager.default.fileExists(atPath: secondURL.path) == false)

        #expect(recorder.urls.count == 2)
        #expect(recorder.urls[0] != recorder.urls[1])
        for trashedURL in recorder.urls {
            #expect(FileManager.default.fileExists(atPath: trashedURL.path))
        }
    }
}

private final class Recorder {
    var urls: [URL] = []
}

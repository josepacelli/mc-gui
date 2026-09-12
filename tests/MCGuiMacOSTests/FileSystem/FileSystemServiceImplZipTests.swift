import Foundation
import Testing
import MCGuiCore
@testable import MCGuiMacOS

@Suite("FileSystemServiceImpl - zip")
struct FileSystemServiceImplZipTests {

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("fsimpl-zip-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @discardableResult
    private func writeFile(named name: String, content: String, in directory: URL) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try Data(content.utf8).write(to: url)
        return url
    }

    private func missingEntry(named name: String, in directory: URL) -> FileEntry {
        FileEntry(
            name: name,
            path: directory.appendingPathComponent(name),
            size: 0,
            creationDate: Date(timeIntervalSince1970: 0),
            modificationDate: Date(timeIntervalSince1970: 0),
            permissions: [],
            type: .file,
            isHidden: false,
            isSymlink: false,
            symlinkTarget: nil
        )
    }

    private func listedNames(inZipAt url: URL) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-l", url.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }


    @Test("zipping a single file produces a valid, non-empty archive at the exact requested destination")
    func zipSingleFileProducesArchiveAtExactDestination() async throws {
        let srcDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: srcDir) }

        try writeFile(named: "notes.txt", content: "hello", in: srcDir)
        let service = FileSystemServiceImpl()
        let sourceEntry = try #require(try await service.listDirectory(srcDir).first)
        let destination = srcDir.appendingPathComponent("notes.txt.zip")

        try await service.zip([sourceEntry], to: destination)

        #expect(FileManager.default.fileExists(atPath: destination.path))
        let attributes = try FileManager.default.attributesOfItem(atPath: destination.path)
        let size = attributes[.size] as? Int ?? 0
        #expect(size > 0)
        let listing = try listedNames(inZipAt: destination)
        #expect(listing.contains("notes.txt"))
    }

    @Test("zipping multiple sources in one call produces one archive containing all of them")
    func zipMultipleSourcesProducesOneArchiveContainingAll() async throws {
        let srcDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: srcDir) }

        try writeFile(named: "a.txt", content: "1", in: srcDir)
        try writeFile(named: "b.txt", content: "2", in: srcDir)
        let service = FileSystemServiceImpl()
        let sources = try await service.listDirectory(srcDir).sorted { $0.name < $1.name }
        let destination = srcDir.appendingPathComponent("Archive.zip")

        try await service.zip(sources, to: destination)

        #expect(FileManager.default.fileExists(atPath: destination.path))
        let listing = try listedNames(inZipAt: destination)
        #expect(listing.contains("a.txt"))
        #expect(listing.contains("b.txt"))
    }

    @Test("a source that doesn't exist makes zip exit non-zero, throwing zipFailed with no file left at destination")
    func zipMissingSourceThrowsZipFailedAndLeavesNoFile() async throws {
        let srcDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: srcDir) }

        let missing = missingEntry(named: "missing.txt", in: srcDir)
        let destination = srcDir.appendingPathComponent("Missing.zip")
        let service = FileSystemServiceImpl()

        do {
            try await service.zip([missing], to: destination)
            Issue.record("Expected FileSystemServiceError.zipFailed to be thrown")
        } catch let error as FileSystemServiceError {
            guard case .zipFailed = error else {
                Issue.record("Expected .zipFailed, got \(error)")
                return
            }
        }

        #expect(FileManager.default.fileExists(atPath: destination.path) == false)
    }
}

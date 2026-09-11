import Foundation
import Testing
import MCGuiCore
@testable import MCGuiMacOS

@Suite("FileSystemServiceImpl - listDirectory, createDirectory")
struct FileSystemServiceImplTests {

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("fsimpl-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: - listDirectory

    @Test("listDirectory returns entries with name, size, dates, permissions, hidden, and symlink populated")
    func listDirectoryReturnsPopulatedEntries() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let fileURL = dir.appendingPathComponent("visible.txt")
        try Data("hello".utf8).write(to: fileURL)
        let hiddenURL = dir.appendingPathComponent(".hidden")
        try Data().write(to: hiddenURL)
        let linkURL = dir.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: linkURL, withDestinationURL: fileURL)

        let service = FileSystemServiceImpl()
        let entries = try await service.listDirectory(dir)

        #expect(entries.count == 3)

        let visible = try #require(entries.first { $0.name == "visible.txt" })
        #expect(visible.size == 5)
        #expect(visible.isHidden == false)
        #expect(visible.isSymlink == false)
        #expect(visible.type == .file)
        #expect(visible.permissions.contains(.ownerRead))
        #expect(visible.modificationDate.timeIntervalSince1970 > 0)

        let hidden = try #require(entries.first { $0.name == ".hidden" })
        #expect(hidden.isHidden == true)

        let link = try #require(entries.first { $0.name == "link" })
        #expect(link.isSymlink == true)
        #expect(link.type == .symlink)
        #expect(link.symlinkTarget?.lastPathComponent == "visible.txt")
    }

    @Test("listDirectory on an empty directory returns an empty array")
    func listDirectoryOnEmptyDirectory() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let service = FileSystemServiceImpl()
        let entries = try await service.listDirectory(dir)

        #expect(entries == [])
    }

    @Test("listDirectory on a permission-denied directory throws a typed permissionDenied error")
    func listDirectoryPermissionDenied() async throws {
        let dir = try makeTempDirectory()
        let restricted = dir.appendingPathComponent("restricted", isDirectory: true)
        try FileManager.default.createDirectory(at: restricted, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: restricted.path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: restricted.path)
            try? FileManager.default.removeItem(at: dir)
        }

        let service = FileSystemServiceImpl()

        do {
            _ = try await service.listDirectory(restricted)
            Issue.record("Expected FileSystemServiceError.permissionDenied to be thrown")
        } catch let error as FileSystemServiceError {
            #expect(error == .permissionDenied(restricted))
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    // MARK: - createDirectory

    @Test("createDirectory creates a new directory")
    func createDirectorySucceeds() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let newDir = dir.appendingPathComponent("child", isDirectory: true)

        let service = FileSystemServiceImpl()
        try await service.createDirectory(newDir)

        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: newDir.path, isDirectory: &isDirectory)
        #expect(exists)
        #expect(isDirectory.boolValue)
    }

    @Test("createDirectory throws a typed alreadyExists error when the target already exists")
    func createDirectoryAlreadyExists() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let existing = dir.appendingPathComponent("existing", isDirectory: true)
        try FileManager.default.createDirectory(at: existing, withIntermediateDirectories: true)

        let service = FileSystemServiceImpl()

        do {
            try await service.createDirectory(existing)
            Issue.record("Expected FileSystemServiceError.alreadyExists to be thrown")
        } catch let error as FileSystemServiceError {
            #expect(error == .alreadyExists(existing))
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
}

import Foundation
import Testing
import MCGuiCore
@testable import MCGuiMacOS

@Suite("ViewerServiceImpl - image loading, navigation, search")
struct ViewerServiceImplNavigationSearchTests {

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("viewerimpl-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private var onePixelPNGData: Data {
        let base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="
        return Data(base64Encoded: base64)!
    }


    @Test("load on an image file returns .image with the exact, NSImage-decodable bytes")
    func loadImageFileReturnsImageContent() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let fileURL = dir.appendingPathComponent("pixel.png")
        let pngData = onePixelPNGData
        try pngData.write(to: fileURL)

        let service = ViewerServiceImpl()
        let content = try await service.load(fileURL)

        #expect(content == .image(pngData))
    }


    @Test("nextFile loads the following file in the list set via setFileList")
    func nextFileLoadsFollowingFile() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let aURL = dir.appendingPathComponent("a.txt")
        let bURL = dir.appendingPathComponent("b.txt")
        try Data("A".utf8).write(to: aURL)
        try Data("B".utf8).write(to: bURL)

        let service = ViewerServiceImpl()
        service.setFileList([aURL, bURL])
        _ = try await service.load(aURL)

        let next = try await service.nextFile()

        #expect(next == .text("B"))
    }

    @Test("previousFile loads the preceding file in the list set via setFileList")
    func previousFileLoadsPrecedingFile() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let aURL = dir.appendingPathComponent("a.txt")
        let bURL = dir.appendingPathComponent("b.txt")
        try Data("A".utf8).write(to: aURL)
        try Data("B".utf8).write(to: bURL)

        let service = ViewerServiceImpl()
        service.setFileList([aURL, bURL])
        _ = try await service.load(bURL)

        let previous = try await service.previousFile()

        #expect(previous == .text("A"))
    }

    @Test("nextFile at the last file stops at bounds and reloads the same file, without throwing")
    func nextFileAtLastFileStopsAtBounds() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let aURL = dir.appendingPathComponent("a.txt")
        let bURL = dir.appendingPathComponent("b.txt")
        try Data("A".utf8).write(to: aURL)
        try Data("B".utf8).write(to: bURL)

        let service = ViewerServiceImpl()
        service.setFileList([aURL, bURL])
        _ = try await service.load(bURL)

        let atLast = try await service.nextFile()

        #expect(atLast == .text("B"))
    }

    @Test("previousFile at the first file stops at bounds and reloads the same file, without throwing")
    func previousFileAtFirstFileStopsAtBounds() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let aURL = dir.appendingPathComponent("a.txt")
        let bURL = dir.appendingPathComponent("b.txt")
        try Data("A".utf8).write(to: aURL)
        try Data("B".utf8).write(to: bURL)

        let service = ViewerServiceImpl()
        service.setFileList([aURL, bURL])
        _ = try await service.load(aURL)

        let atFirst = try await service.previousFile()

        #expect(atFirst == .text("A"))
    }

    @Test("nextFile before any load throws noNavigationContext")
    func nextFileBeforeLoadThrowsNoNavigationContext() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let aURL = dir.appendingPathComponent("a.txt")
        try Data("A".utf8).write(to: aURL)

        let service = ViewerServiceImpl()
        service.setFileList([aURL])

        do {
            _ = try await service.nextFile()
            Issue.record("Expected ViewerServiceError.noNavigationContext to be thrown")
        } catch let error as ViewerServiceError {
            #expect(error == .noNavigationContext)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("previousFile with no file list set throws noNavigationContext")
    func previousFileWithNoFileListThrowsNoNavigationContext() async throws {
        let service = ViewerServiceImpl()

        do {
            _ = try await service.previousFile()
            Issue.record("Expected ViewerServiceError.noNavigationContext to be thrown")
        } catch let error as ViewerServiceError {
            #expect(error == .noNavigationContext)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }


    @Test("search with zero matches returns an empty array")
    func searchZeroMatchesReturnsEmpty() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let fileURL = dir.appendingPathComponent("text.txt")
        try Data("hello world".utf8).write(to: fileURL)

        let service = ViewerServiceImpl()
        _ = try await service.load(fileURL)

        #expect(service.search("xyz") == [])
    }

    @Test("search with one match returns its exact range")
    func searchOneMatchReturnsExactRange() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let fileURL = dir.appendingPathComponent("text.txt")
        try Data("hello world".utf8).write(to: fileURL)

        let service = ViewerServiceImpl()
        _ = try await service.load(fileURL)

        #expect(service.search("world") == [SearchMatch(location: 6, length: 5)])
    }

    @Test("search with N matches returns every occurrence's exact range, case-insensitively")
    func searchNMatchesReturnsEveryOccurrenceCaseInsensitively() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let fileURL = dir.appendingPathComponent("text.txt")
        try Data("Cat cat CAT".utf8).write(to: fileURL)

        let service = ViewerServiceImpl()
        _ = try await service.load(fileURL)

        #expect(service.search("cat") == [
            SearchMatch(location: 0, length: 3),
            SearchMatch(location: 4, length: 3),
            SearchMatch(location: 8, length: 3)
        ])
    }

    @Test("search before any load returns an empty array")
    func searchBeforeLoadReturnsEmpty() {
        let service = ViewerServiceImpl()

        #expect(service.search("anything") == [])
    }

    @Test("search after loading an image returns an empty array")
    func searchAfterLoadingImageReturnsEmpty() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let fileURL = dir.appendingPathComponent("pixel.png")
        try onePixelPNGData.write(to: fileURL)

        let service = ViewerServiceImpl()
        _ = try await service.load(fileURL)

        #expect(service.search("PNG") == [])
    }

    @Test("search after loading a binary (hex mode) file returns an empty array")
    func searchAfterLoadingBinaryReturnsEmpty() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let fileURL = dir.appendingPathComponent("binary.dat")
        try Data([0x00, 0x01, 0x02, 0x03]).write(to: fileURL)

        let service = ViewerServiceImpl()
        _ = try await service.load(fileURL)

        #expect(service.search("anything") == [])
    }
}

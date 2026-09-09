import Foundation
import Testing
import MCGuiCore
@testable import MCGuiMacOS

@Suite("FileSystemServiceImpl - getVolumes")
struct FileSystemServiceImplVolumesTests {

    @Test("getVolumes returns all mounted volumes with a name and root URL, always including the boot volume")
    func getVolumesIncludesBootVolume() {
        let service = FileSystemServiceImpl()

        let volumes = service.getVolumes()

        #expect(volumes.isEmpty == false)
        for volume in volumes {
            #expect(volume.name.isEmpty == false)
        }

        let bootVolume = volumes.first { $0.mountPoint.path == "/" }
        #expect(bootVolume != nil)
    }

    // MARK: - trash (protocol-conformance completion, see SPEC_DEVIATION in FileSystemServiceImpl.swift)

    @Test("trash moves a file to the macOS Trash instead of deleting it")
    func trashMovesFileToTrash() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("fsimpl-volumes-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let fileURL = dir.appendingPathComponent("to-trash.txt")
        try Data("bye".utf8).write(to: fileURL)

        let service = FileSystemServiceImpl()
        let result = try await service.trash([fileURL])

        #expect(result.success)
        #expect(result.processedCount == 1)
        #expect(result.failedItems == [])
        #expect(FileManager.default.fileExists(atPath: fileURL.path) == false)
    }
}

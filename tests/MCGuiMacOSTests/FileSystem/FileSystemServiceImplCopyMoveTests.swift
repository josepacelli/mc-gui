import Foundation
import Testing
import MCGuiCore
@testable import MCGuiMacOS

@Suite("FileSystemServiceImpl - copy/move")
struct FileSystemServiceImplCopyMoveTests {

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("fsimpl-copymove-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @discardableResult
    private func writeFile(named name: String, content: String, in directory: URL) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try Data(content.utf8).write(to: url)
        return url
    }

    private func plan(
        sources: [FileEntry],
        destination: URL,
        mode: OperationMode,
        options: CopyMoveOptions = CopyMoveOptions(preserveAttributes: false, followSymlinks: false, updateOnly: false),
        renames: [UUID: String] = [:]
    ) -> CopyMovePlan {
        CopyMovePlan(sources: sources, destinationDirectory: destination, mode: mode, options: options, renames: renames)
    }

    // MARK: - preserveAttributes (FO-03)

    @Test("copy preserves permissions and modification date when preserveAttributes is true")
    func copyPreservesAttributes() async throws {
        let srcDir = try makeTempDirectory()
        let dstDir = try makeTempDirectory()
        defer {
            try? FileManager.default.removeItem(at: srcDir)
            try? FileManager.default.removeItem(at: dstDir)
        }

        let sourceURL = try writeFile(named: "a.txt", content: "hi", in: srcDir)
        try FileManager.default.setAttributes([.posixPermissions: 0o640], ofItemAtPath: sourceURL.path)
        let oldDate = Date(timeIntervalSince1970: 1_000_000)
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: sourceURL.path)

        let service = FileSystemServiceImpl()
        let sourceEntry = try #require(try await service.listDirectory(srcDir).first)

        let options = CopyMoveOptions(preserveAttributes: true, followSymlinks: false, updateOnly: false)
        let result = try await service.copy(plan(sources: [sourceEntry], destination: dstDir, mode: .copy, options: options))

        #expect(result.success)
        #expect(result.processedCount == 1)

        let destAttributes = try FileManager.default.attributesOfItem(
            atPath: dstDir.appendingPathComponent("a.txt").path
        )
        let destPermissions = (destAttributes[.posixPermissions] as? NSNumber)?.intValue
        #expect(destPermissions == 0o640)
        let destModDate = destAttributes[.modificationDate] as? Date
        #expect(abs((destModDate?.timeIntervalSince1970 ?? 0) - oldDate.timeIntervalSince1970) < 1.0)
    }

    // MARK: - same-volume / cross-volume move (FO-04)

    @Test("move on the same volume renames via moveItem rather than copying")
    func moveSameVolumeRenames() async throws {
        let srcDir = try makeTempDirectory()
        let dstDir = try makeTempDirectory()
        defer {
            try? FileManager.default.removeItem(at: srcDir)
            try? FileManager.default.removeItem(at: dstDir)
        }

        let sourceURL = try writeFile(named: "a.txt", content: "hi", in: srcDir)

        let recorder = CallRecorder()
        let service = FileSystemServiceImpl(
            copyItem: { src, dst in recorder.copyCalls += 1; try FileManager.default.copyItem(at: src, to: dst) },
            moveItem: { src, dst in recorder.moveCalls += 1; try FileManager.default.moveItem(at: src, to: dst) },
            isSameVolume: { _, _ in true }
        )

        let sourceEntry = try #require(try await service.listDirectory(srcDir).first)
        let result = try await service.move(plan(sources: [sourceEntry], destination: dstDir, mode: .move))

        #expect(result.success)
        #expect(result.processedCount == 1)
        #expect(recorder.moveCalls == 1)
        #expect(recorder.copyCalls == 0)
        #expect(FileManager.default.fileExists(atPath: sourceURL.path) == false)
        let destURL = dstDir.appendingPathComponent("a.txt")
        #expect(FileManager.default.fileExists(atPath: destURL.path))
        #expect(try String(contentsOf: destURL, encoding: .utf8) == "hi")
    }

    @Test("move across volumes copies the file then deletes the original")
    func moveCrossVolumeCopiesThenDeletes() async throws {
        let srcDir = try makeTempDirectory()
        let dstDir = try makeTempDirectory()
        defer {
            try? FileManager.default.removeItem(at: srcDir)
            try? FileManager.default.removeItem(at: dstDir)
        }

        let sourceURL = try writeFile(named: "a.txt", content: "hi", in: srcDir)

        let recorder = CallRecorder()
        let service = FileSystemServiceImpl(
            copyItem: { src, dst in recorder.copyCalls += 1; try FileManager.default.copyItem(at: src, to: dst) },
            moveItem: { src, dst in recorder.moveCalls += 1; try FileManager.default.moveItem(at: src, to: dst) },
            isSameVolume: { _, _ in false }
        )

        let sourceEntry = try #require(try await service.listDirectory(srcDir).first)
        let result = try await service.move(plan(sources: [sourceEntry], destination: dstDir, mode: .move))

        #expect(result.success)
        #expect(result.processedCount == 1)
        #expect(recorder.copyCalls == 1)
        #expect(recorder.moveCalls == 0)
        #expect(FileManager.default.fileExists(atPath: sourceURL.path) == false)
        let destURL = dstDir.appendingPathComponent("a.txt")
        #expect(FileManager.default.fileExists(atPath: destURL.path))
        #expect(try String(contentsOf: destURL, encoding: .utf8) == "hi")
    }

    // MARK: - overwrite / skip conflict resolution (FO-06/FO-07)

    @Test("copy overwrites an existing destination file by default")
    func copyOverwritesExistingDestinationByDefault() async throws {
        let srcDir = try makeTempDirectory()
        let dstDir = try makeTempDirectory()
        defer {
            try? FileManager.default.removeItem(at: srcDir)
            try? FileManager.default.removeItem(at: dstDir)
        }

        try writeFile(named: "a.txt", content: "new-content", in: srcDir)
        let destURL = try writeFile(named: "a.txt", content: "old-content", in: dstDir)

        let service = FileSystemServiceImpl()
        let sourceEntry = try #require(try await service.listDirectory(srcDir).first)
        let result = try await service.copy(plan(sources: [sourceEntry], destination: dstDir, mode: .copy))

        #expect(result.success)
        #expect(result.processedCount == 1)
        #expect(try String(contentsOf: destURL, encoding: .utf8) == "new-content")
    }

    @Test("copy with updateOnly skips a destination that is already up to date")
    func copySkipsUpToDateDestinationWithUpdateOnly() async throws {
        let srcDir = try makeTempDirectory()
        let dstDir = try makeTempDirectory()
        defer {
            try? FileManager.default.removeItem(at: srcDir)
            try? FileManager.default.removeItem(at: dstDir)
        }

        let sourceURL = try writeFile(named: "a.txt", content: "new-content", in: srcDir)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 1_000)],
            ofItemAtPath: sourceURL.path
        )
        let destURL = try writeFile(named: "a.txt", content: "old-content", in: dstDir)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 2_000)],
            ofItemAtPath: destURL.path
        )

        let service = FileSystemServiceImpl()
        let sourceEntry = try #require(try await service.listDirectory(srcDir).first)
        let options = CopyMoveOptions(preserveAttributes: false, followSymlinks: false, updateOnly: true)
        let result = try await service.copy(plan(sources: [sourceEntry], destination: dstDir, mode: .copy, options: options))

        #expect(result.success)
        #expect(result.processedCount == 1)
        #expect(result.failedItems == [])
        #expect(try String(contentsOf: destURL, encoding: .utf8) == "old-content")
    }

    // MARK: - rename conflict resolution (FO-08)

    @Test("copy writes to the renamed destination name when plan.renames has an entry for the source")
    func copyUsesRenameWhenPresent() async throws {
        let srcDir = try makeTempDirectory()
        let dstDir = try makeTempDirectory()
        defer {
            try? FileManager.default.removeItem(at: srcDir)
            try? FileManager.default.removeItem(at: dstDir)
        }

        try writeFile(named: "a.txt", content: "new-content", in: srcDir)
        let existingDestURL = try writeFile(named: "a.txt", content: "old-content", in: dstDir)

        let service = FileSystemServiceImpl()
        let sourceEntry = try #require(try await service.listDirectory(srcDir).first)
        let result = try await service.copy(
            plan(sources: [sourceEntry], destination: dstDir, mode: .copy, renames: [sourceEntry.id: "a (1).txt"])
        )

        #expect(result.success)
        #expect(result.processedCount == 1)
        // the original destination file is untouched - the rename avoided the conflict
        // entirely rather than overwriting it
        #expect(try String(contentsOf: existingDestURL, encoding: .utf8) == "old-content")
        let renamedDestURL = dstDir.appendingPathComponent("a (1).txt")
        #expect(try String(contentsOf: renamedDestURL, encoding: .utf8) == "new-content")
    }

    // MARK: - progress reporting and cancellation (FO-14, FO-16)

    @Test("copy(_:onProgress:) reports one snapshot per source, in order, with the running byte total")
    func copyWithProgressReportsOneSnapshotPerSource() async throws {
        let srcDir = try makeTempDirectory()
        let dstDir = try makeTempDirectory()
        defer {
            try? FileManager.default.removeItem(at: srcDir)
            try? FileManager.default.removeItem(at: dstDir)
        }

        try writeFile(named: "a.txt", content: "1234", in: srcDir)
        try writeFile(named: "b.txt", content: "12345678", in: srcDir)

        let service = FileSystemServiceImpl()
        let sources = try await service.listDirectory(srcDir).sorted { $0.name < $1.name }

        // `onProgress` is called synchronously, in order, from within `copy`'s own loop -
        // no concurrency to guard against, so a plain class is enough to record calls.
        let recorder = ProgressRecorder()
        let result = try await service.copy(
            plan(sources: sources, destination: dstDir, mode: .copy),
            onProgress: { recorder.snapshots.append($0) }
        )

        #expect(result.success)
        #expect(result.processedCount == 2)
        #expect(recorder.snapshots.count == 2)
        #expect(recorder.snapshots.map(\.currentFile) == ["a.txt", "b.txt"])
        #expect(recorder.snapshots.map(\.bytesTransferred) == [4, 12])
        #expect(recorder.snapshots.allSatisfy { $0.totalBytes == 12 })
    }

    @Test("cancelling the calling Task stops copy(_:onProgress:) before processing every source")
    func copyWithProgressStopsOnCancellation() async throws {
        let srcDir = try makeTempDirectory()
        let dstDir = try makeTempDirectory()
        defer {
            try? FileManager.default.removeItem(at: srcDir)
            try? FileManager.default.removeItem(at: dstDir)
        }

        try writeFile(named: "a.txt", content: "1", in: srcDir)
        try writeFile(named: "b.txt", content: "2", in: srcDir)

        let service = FileSystemServiceImpl()
        let sources = try await service.listDirectory(srcDir).sorted { $0.name < $1.name }

        let task = Task {
            try await service.copy(
                plan(sources: sources, destination: dstDir, mode: .copy),
                onProgress: { _ in }
            )
        }
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Expected CancellationError to be thrown")
        } catch is CancellationError {
            // expected - checkCancellation() fires before the first source is processed
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }

        #expect(FileManager.default.fileExists(atPath: dstDir.appendingPathComponent("a.txt").path) == false)
        #expect(FileManager.default.fileExists(atPath: dstDir.appendingPathComponent("b.txt").path) == false)
    }

    // MARK: - path length / volume disconnection (Edge Cases 7, 6)

    @Test("copy throws a typed pathTooLong error when the destination path exceeds PATH_MAX")
    func copyFailsWithPathTooLong() async throws {
        let srcDir = try makeTempDirectory()
        let dstDir = try makeTempDirectory()
        defer {
            try? FileManager.default.removeItem(at: srcDir)
            try? FileManager.default.removeItem(at: dstDir)
        }

        try writeFile(named: "a.txt", content: "hi", in: srcDir)

        let service = FileSystemServiceImpl()
        let sourceEntry = try #require(try await service.listDirectory(srcDir).first)
        // a rename long enough to push the destination path past PATH_MAX regardless of
        // where the temp directory happens to live
        let hugeName = String(repeating: "a", count: 5_000) + ".txt"

        do {
            _ = try await service.copy(
                plan(sources: [sourceEntry], destination: dstDir, mode: .copy, renames: [sourceEntry.id: hugeName])
            )
            Issue.record("Expected FileSystemServiceError.pathTooLong to be thrown")
        } catch let error as FileSystemServiceError {
            guard case .pathTooLong = error else {
                Issue.record("Expected .pathTooLong, got \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }

        #expect(FileManager.default.fileExists(atPath: dstDir.appendingPathComponent(hugeName).path) == false)
    }

    @Test("copy throws a typed volumeDisconnected error on ENOTCONN and aborts the rest of the batch")
    func copyFailsWithVolumeDisconnected() async throws {
        let srcDir = try makeTempDirectory()
        let dstDir = try makeTempDirectory()
        defer {
            try? FileManager.default.removeItem(at: srcDir)
            try? FileManager.default.removeItem(at: dstDir)
        }

        try writeFile(named: "a.txt", content: "hi", in: srcDir)
        try writeFile(named: "b.txt", content: "hi", in: srcDir)
        let sources = try await FileSystemServiceImpl().listDirectory(srcDir).sorted { $0.name < $1.name }

        let recorder = CallRecorder()
        let service = FileSystemServiceImpl(copyItem: { _, _ in
            recorder.copyCalls += 1
            throw POSIXError(.ENOTCONN)
        })

        do {
            _ = try await service.copy(plan(sources: sources, destination: dstDir, mode: .copy))
            Issue.record("Expected FileSystemServiceError.volumeDisconnected to be thrown")
        } catch let error as FileSystemServiceError {
            guard case .volumeDisconnected = error else {
                Issue.record("Expected .volumeDisconnected, got \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }

        // aborted after the first source - the second was never attempted
        #expect(recorder.copyCalls == 1)
    }

    // MARK: - EBUSY-simulated retry

    @Test("copy retries a transient EBUSY failure and succeeds once the file is free")
    func copyRetriesEBUSYThenSucceeds() async throws {
        let srcDir = try makeTempDirectory()
        let dstDir = try makeTempDirectory()
        defer {
            try? FileManager.default.removeItem(at: srcDir)
            try? FileManager.default.removeItem(at: dstDir)
        }

        try writeFile(named: "a.txt", content: "content", in: srcDir)

        let recorder = CallRecorder()
        let service = FileSystemServiceImpl(copyItem: { src, dst in
            recorder.copyCalls += 1
            if recorder.copyCalls < 3 {
                throw POSIXError(.EBUSY)
            }
            try FileManager.default.copyItem(at: src, to: dst)
        })

        let sourceEntry = try #require(try await service.listDirectory(srcDir).first)
        let result = try await service.copy(plan(sources: [sourceEntry], destination: dstDir, mode: .copy))

        #expect(result.success)
        #expect(result.processedCount == 1)
        #expect(recorder.copyCalls == 3)
        let destURL = dstDir.appendingPathComponent("a.txt")
        #expect(try String(contentsOf: destURL, encoding: .utf8) == "content")
    }

    @Test("copy reports a typed fileInUse failure once EBUSY retries are exhausted")
    func copyFailsAfterExhaustingEBUSYRetries() async throws {
        let srcDir = try makeTempDirectory()
        let dstDir = try makeTempDirectory()
        defer {
            try? FileManager.default.removeItem(at: srcDir)
            try? FileManager.default.removeItem(at: dstDir)
        }

        try writeFile(named: "a.txt", content: "content", in: srcDir)

        let recorder = CallRecorder()
        let service = FileSystemServiceImpl(copyItem: { _, _ in
            recorder.copyCalls += 1
            throw POSIXError(.EBUSY)
        })

        let sourceEntry = try #require(try await service.listDirectory(srcDir).first)
        let result = try await service.copy(plan(sources: [sourceEntry], destination: dstDir, mode: .copy))

        #expect(result.success == false)
        #expect(result.processedCount == 0)
        #expect(recorder.copyCalls == 3)
        #expect(result.failedItems.count == 1)
        #expect(result.failedItems.first?.reason.contains("fileInUse") == true)
        #expect(FileManager.default.fileExists(atPath: dstDir.appendingPathComponent("a.txt").path) == false)
    }

    // MARK: - ENOSPC-simulated failure

    @Test("copy throws a typed insufficientDiskSpace error when available space is less than required")
    func copyFailsWithInsufficientDiskSpace() async throws {
        let srcDir = try makeTempDirectory()
        let dstDir = try makeTempDirectory()
        defer {
            try? FileManager.default.removeItem(at: srcDir)
            try? FileManager.default.removeItem(at: dstDir)
        }

        try writeFile(named: "a.txt", content: "not-empty-content", in: srcDir)

        let service = FileSystemServiceImpl(availableFreeSpace: { _ in 0 })
        let sourceEntry = try #require(try await service.listDirectory(srcDir).first)

        do {
            _ = try await service.copy(plan(sources: [sourceEntry], destination: dstDir, mode: .copy))
            Issue.record("Expected FileSystemServiceError.insufficientDiskSpace to be thrown")
        } catch let error as FileSystemServiceError {
            #expect(error == .insufficientDiskSpace)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }

        #expect(FileManager.default.fileExists(atPath: dstDir.appendingPathComponent("a.txt").path) == false)
    }
}

/// Records injected-closure invocation counts. A plain reference type is enough here:
/// each test drives its `FileSystemServiceImpl` sequentially within a single async task.
private final class CallRecorder {
    var copyCalls = 0
    var moveCalls = 0
}

/// Records `onProgress` snapshots in call order - see the "progress reporting" tests.
private final class ProgressRecorder {
    var snapshots: [OperationProgress] = []
}

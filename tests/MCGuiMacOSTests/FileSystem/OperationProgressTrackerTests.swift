import Foundation
import Testing
import MCGuiCore
@testable import MCGuiMacOS

/// Unit tests for `OperationProgressTracker`'s pure snapshot math (FO-14): running byte
/// total, elapsed-time-based speed, and remaining-bytes/speed ETA.
@Suite("OperationProgressTracker")
struct OperationProgressTrackerTests {

    private func makeEntry(name: String, size: Int64, type: FileType = .file) -> FileEntry {
        FileEntry(
            name: name,
            path: URL(fileURLWithPath: "/tmp/\(name)"),
            size: size,
            creationDate: .distantPast,
            modificationDate: .distantPast,
            permissions: [],
            type: type,
            isHidden: false,
            isSymlink: false,
            symlinkTarget: nil
        )
    }

    @Test("recordProcessed accumulates bytesTransferred and reports totalFiles/totalBytes from all sources")
    func recordProcessedAccumulatesBytes() {
        let a = makeEntry(name: "a.txt", size: 100)
        let b = makeEntry(name: "b.txt", size: 300)
        let tracker = OperationProgressTracker(sources: [a, b], now: { Date(timeIntervalSince1970: 0) })

        let first = tracker.recordProcessed(a)
        #expect(first.currentFile == "a.txt")
        #expect(first.totalFiles == 2)
        #expect(first.bytesTransferred == 100)
        #expect(first.totalBytes == 400)

        let second = tracker.recordProcessed(b)
        #expect(second.currentFile == "b.txt")
        #expect(second.bytesTransferred == 400)
    }

    @Test("recordProcessed excludes directory sources from the byte total")
    func recordProcessedExcludesDirectories() {
        let dir = makeEntry(name: "folder", size: 999, type: .directory)
        let file = makeEntry(name: "a.txt", size: 100)
        let tracker = OperationProgressTracker(sources: [dir, file], now: { Date(timeIntervalSince1970: 0) })

        let afterDir = tracker.recordProcessed(dir)
        #expect(afterDir.bytesTransferred == 0)
        #expect(afterDir.totalBytes == 100)
    }

    @Test("speed and eta are 0 when no time has elapsed")
    func speedAndETAZeroWithNoElapsedTime() {
        let a = makeEntry(name: "a.txt", size: 100)
        let fixedTime = Date(timeIntervalSince1970: 1_000)
        let tracker = OperationProgressTracker(sources: [a], now: { fixedTime })

        let progress = tracker.recordProcessed(a)

        #expect(progress.speed == 0)
        #expect(progress.eta == 0)
    }

    @Test("speed reflects bytesTransferred over elapsed time, eta reflects remaining bytes at that speed")
    func speedAndETAReflectElapsedTime() {
        let a = makeEntry(name: "a.txt", size: 100)
        let b = makeEntry(name: "b.txt", size: 100)
        var now = Date(timeIntervalSince1970: 0)
        let tracker = OperationProgressTracker(sources: [a, b], now: { now })

        now = Date(timeIntervalSince1970: 10) // 10s elapsed, 100 bytes transferred -> 10 B/s
        let progress = tracker.recordProcessed(a)

        #expect(progress.speed == 10)
        // 100 bytes remaining at 10 B/s -> 10s ETA
        #expect(progress.eta == 10)
    }
}

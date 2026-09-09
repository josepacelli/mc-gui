import Foundation
import Testing
@testable import MCGuiUI
import MCGuiCore

/// Unit tests for the pure helper functions `PanelView` uses to wire F5/F6/F7/F8 file
/// operations (T33). `PanelView.body` itself is thin declarative glue over these -
/// consistent with the Phase 5 dialog views, it has no XCUITest coverage yet (no Xcode
/// project/scheme exists in this pure-SPM setup); these functions carry the actual logic.
@Suite("PanelView file operations")
@MainActor
struct PanelViewFileOperationsTests {

    private let directory = URL(fileURLWithPath: "/tmp/dest")

    // MARK: - makeCopyMoveDialog (FO-01, FO-02)

    @Test("makeCopyMoveDialog with a non-empty selection builds a dialog in copy mode")
    func makeCopyMoveDialogCopyMode() {
        let entries = [makeTestEntry(name: "a.txt"), makeTestEntry(name: "b.txt")]

        let dialog = PanelView.makeCopyMoveDialog(selection: entries, mode: .copy, destinationDirectory: directory)

        #expect(dialog?.sources == entries)
        #expect(dialog?.mode == .copy)
        #expect(dialog?.destinationDirectory == directory)
    }

    @Test("makeCopyMoveDialog with a non-empty selection builds a dialog in move mode")
    func makeCopyMoveDialogMoveMode() {
        let entries = [makeTestEntry(name: "a.txt")]

        let dialog = PanelView.makeCopyMoveDialog(selection: entries, mode: .move, destinationDirectory: directory)

        #expect(dialog?.mode == .move)
        #expect(dialog?.sources == entries)
    }

    @Test("makeCopyMoveDialog with an empty selection returns nil (F5/F6 no-op)")
    func makeCopyMoveDialogEmptySelectionReturnsNil() {
        let dialog = PanelView.makeCopyMoveDialog(selection: [], mode: .copy, destinationDirectory: directory)

        #expect(dialog == nil)
    }

    // MARK: - makeMkdirDialog (FO-10)

    @Test("makeMkdirDialog builds a dialog for the given parent directory regardless of selection")
    func makeMkdirDialogBuildsDialog() {
        let service = MockFileSystemService()

        let dialog = PanelView.makeMkdirDialog(fileSystemService: service, parentDirectory: directory)

        #expect(dialog.parentDirectory == directory)
    }

    // MARK: - makeDeleteDialog (FO-12)

    @Test("makeDeleteDialog with a non-empty selection builds a dialog with those entries")
    func makeDeleteDialogBuildsDialog() {
        let entries = [makeTestEntry(name: "a.txt"), makeTestEntry(name: "b.txt")]
        let service = MockTrashService()

        let dialog = PanelView.makeDeleteDialog(selection: entries, trashService: service)

        #expect(dialog?.entries == entries)
        #expect(dialog?.count == 2)
    }

    @Test("makeDeleteDialog with an empty selection returns nil (F8 no-op)")
    func makeDeleteDialogEmptySelectionReturnsNil() {
        let dialog = PanelView.makeDeleteDialog(selection: [], trashService: MockTrashService())

        #expect(dialog == nil)
    }

    // MARK: - fo15Message (FO-15)

    @Test("fo15Message returns nil for a successful operation")
    func fo15MessageNilOnSuccess() {
        let result = OperationResult(success: true, errorMessage: nil, processedCount: 2, failedItems: [])

        #expect(PanelView.fo15Message(from: result) == nil)
    }

    @Test("fo15Message includes the specific file path and reason for a single failure")
    func fo15MessageSingleFailureIncludesPathAndReason() {
        let result = OperationResult(
            success: false,
            errorMessage: "Some items failed to copy",
            processedCount: 1,
            failedItems: [FailedItem(path: "/tmp/dest/locked.txt", reason: "fileInUse")]
        )

        let message = PanelView.fo15Message(from: result)

        #expect(message?.contains("/tmp/dest/locked.txt") == true)
        #expect(message?.contains("fileInUse") == true)
    }

    @Test("fo15Message includes the first failing file's path and reason when multiple files fail")
    func fo15MessageMultipleFailuresIncludesFirstFileAndCount() {
        let result = OperationResult(
            success: false,
            errorMessage: "Some items failed to copy",
            processedCount: 0,
            failedItems: [
                FailedItem(path: "/tmp/dest/a.txt", reason: "insufficientDiskSpace"),
                FailedItem(path: "/tmp/dest/b.txt", reason: "insufficientDiskSpace")
            ]
        )

        let message = PanelView.fo15Message(from: result)

        #expect(message?.contains("/tmp/dest/a.txt") == true)
        #expect(message?.contains("insufficientDiskSpace") == true)
    }
}

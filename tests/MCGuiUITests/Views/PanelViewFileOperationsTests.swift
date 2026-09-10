import Foundation
import SwiftUI
import AppKit
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

    // MARK: - targetEntry (FV-01, ED-01 - F3/F4 target selection)

    @Test("targetEntry returns the first selected entry when the selection is non-empty")
    func targetEntryReturnsFirstSelectedEntry() {
        let entries = [makeTestEntry(name: "a.txt"), makeTestEntry(name: "b.txt")]

        let target = PanelView.targetEntry(selection: entries)

        #expect(target == entries[0])
    }

    @Test("targetEntry returns a single selected entry")
    func targetEntryReturnsSingleSelectedEntry() {
        let entry = makeTestEntry(name: "only.txt")

        let target = PanelView.targetEntry(selection: [entry])

        #expect(target == entry)
    }

    @Test("targetEntry with an empty selection returns nil (F3/F4 no-op)")
    func targetEntryEmptySelectionReturnsNil() {
        let target = PanelView.targetEntry(selection: [])

        #expect(target == nil)
    }

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

    // MARK: - action(forKey:) (classic-layout-parity CL-05 - unifies physical F3-F8 with
    // ButtonBar/TopBar's PanelAction dispatch)

    private static func key(_ scalar: Int) -> KeyEquivalent {
        KeyEquivalent(Character(UnicodeScalar(scalar)!))
    }

    @Test("action(forKey:) maps F3-F8 to the matching PanelAction")
    func actionForKeyMapsFunctionKeys() {
        #expect(PanelView.action(forKey: Self.key(NSF3FunctionKey)) == .view)
        #expect(PanelView.action(forKey: Self.key(NSF4FunctionKey)) == .edit)
        #expect(PanelView.action(forKey: Self.key(NSF5FunctionKey)) == .copy)
        #expect(PanelView.action(forKey: Self.key(NSF6FunctionKey)) == .move)
        #expect(PanelView.action(forKey: Self.key(NSF7FunctionKey)) == .mkdir)
        #expect(PanelView.action(forKey: Self.key(NSF8FunctionKey)) == .delete)
    }

    @Test("action(forKey:) returns nil for an unrelated key")
    func actionForKeyNilForUnrelatedKey() {
        #expect(PanelView.action(forKey: "a") == nil)
    }

    // MARK: - parentEntry(for:) (FS-05, KN-11 - the synthetic ".." row)

    @Test("parentEntry returns a '..' entry pointing at the parent directory")
    func parentEntryPointsAtParent() {
        let current = URL(fileURLWithPath: "/Users/pacelli/Documents")

        let entry = PanelView.parentEntry(for: current)

        #expect(entry?.name == "..")
        #expect(entry?.path == URL(fileURLWithPath: "/Users/pacelli"))
        #expect(entry?.type == .directory)
        #expect(entry?.id == PanelView.parentEntryID)
    }

    @Test("parentEntry returns nil at the filesystem root (nothing to go up to)")
    func parentEntryNilAtRoot() {
        let root = URL(fileURLWithPath: "/")

        #expect(PanelView.parentEntry(for: root) == nil)
    }

    // MARK: - activationResult(for:) (FS-04, KN-11 - double-click/Enter)

    @Test("activationResult for a directory navigates to its path")
    func activationResultDirectoryNavigates() {
        let directory = makeTestEntry(name: "Documents", type: .directory)

        #expect(PanelView.activationResult(for: directory) == .navigate(directory.path))
    }

    @Test("activationResult for the '..' entry navigates to its (parent) path")
    func activationResultParentEntryNavigates() {
        let parent = PanelView.parentEntry(for: URL(fileURLWithPath: "/Users/pacelli/Documents"))!

        #expect(PanelView.activationResult(for: parent) == .navigate(parent.path))
    }

    @Test("activationResult for a file opens it in the viewer")
    func activationResultFileViews() {
        let file = makeTestEntry(name: "a.txt", type: .file)

        #expect(PanelView.activationResult(for: file) == .view(file))
    }

    // MARK: - applyResolutions(sources:resolutions:existingNames:) (FO-05..FO-09 - the
    // conflict dialog's Overwrite/Skip/Rename/Cancel choices)

    @Test("overwrite leaves the source untouched (downstream copy/move overwrites unconditionally)")
    func applyResolutionsOverwriteLeavesSourceUnchanged() {
        let a = makeTestEntry(name: "a.txt")
        let b = makeTestEntry(name: "b.txt")

        let outcome = PanelView.applyResolutions(
            sources: [a, b],
            resolutions: [(a, .overwrite)],
            existingNames: ["a.txt"]
        )

        #expect(outcome == .proceed(sources: [a, b], renames: [:]))
    }

    @Test("skip removes the conflicting source from the batch")
    func applyResolutionsSkipRemovesSource() {
        let a = makeTestEntry(name: "a.txt")
        let b = makeTestEntry(name: "b.txt")

        let outcome = PanelView.applyResolutions(
            sources: [a, b],
            resolutions: [(a, .skip)],
            existingNames: ["a.txt"]
        )

        #expect(outcome == .proceed(sources: [b], renames: [:]))
    }

    @Test("rename claims the next available numeric suffix against existingNames")
    func applyResolutionsRenameClaimsSuffix() {
        let a = makeTestEntry(name: "a.txt")

        let outcome = PanelView.applyResolutions(
            sources: [a],
            resolutions: [(a, .rename)],
            existingNames: ["a.txt"]
        )

        #expect(outcome == .proceed(sources: [a], renames: [a.id: "a (1).txt"]))
    }

    @Test("two renamed conflicts in the same batch don't collide with each other")
    func applyResolutionsTwoRenamesDontCollide() {
        let a = makeTestEntry(name: "a.txt")
        let aDuplicateSelection = makeTestEntry(name: "a.txt")

        let outcome = PanelView.applyResolutions(
            sources: [a, aDuplicateSelection],
            resolutions: [(a, .rename), (aDuplicateSelection, .rename)],
            existingNames: ["a.txt"]
        )

        #expect(outcome == .proceed(
            sources: [a, aDuplicateSelection],
            renames: [a.id: "a (1).txt", aDuplicateSelection.id: "a (2).txt"]
        ))
    }

    @Test("cancel aborts the entire batch, not just the file being resolved")
    func applyResolutionsCancelAbortsWholeBatch() {
        let a = makeTestEntry(name: "a.txt")
        let b = makeTestEntry(name: "b.txt")

        let outcome = PanelView.applyResolutions(
            sources: [a, b],
            resolutions: [(a, .skip), (b, .cancel)],
            existingNames: ["a.txt", "b.txt"]
        )

        #expect(outcome == .cancelled)
    }

    // MARK: - escapeAction(hasOpenSheet:filterText:hasSelection:) (KN-12, SF-04)

    @Test("escapeAction dismisses an open sheet first, regardless of filter/selection")
    func escapeActionDismissesSheetFirst() {
        #expect(PanelView.escapeAction(hasOpenSheet: true, filterText: "abc", hasSelection: true) == .dismissSheet)
        #expect(PanelView.escapeAction(hasOpenSheet: true, filterText: "", hasSelection: false) == .dismissSheet)
    }

    @Test("escapeAction clears the filter when no sheet is open but a filter is active")
    func escapeActionClearsFilterWhenNoSheet() {
        #expect(PanelView.escapeAction(hasOpenSheet: false, filterText: "abc", hasSelection: true) == .clearFilter)
    }

    @Test("escapeAction clears the selection when no sheet or filter is active")
    func escapeActionClearsSelectionWhenNoSheetOrFilter() {
        #expect(PanelView.escapeAction(hasOpenSheet: false, filterText: "", hasSelection: true) == .clearSelection)
    }

    @Test("escapeAction does nothing when there's no sheet, filter, or selection")
    func escapeActionNoneWhenNothingToDo() {
        #expect(PanelView.escapeAction(hasOpenSheet: false, filterText: "", hasSelection: false) == .none)
    }
}

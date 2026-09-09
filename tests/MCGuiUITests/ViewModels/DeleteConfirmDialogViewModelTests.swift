import Foundation
import Testing
@testable import MCGuiUI
import MCGuiCore

@Suite("DeleteConfirmDialogViewModel")
@MainActor
struct DeleteConfirmDialogViewModelTests {

    // MARK: - single file (FO-13)

    @Test("confirm with a single file trashes it and completes")
    func confirmSingleFileTrashesIt() async {
        final class Recorder { var trashedURLs: [URL]? }
        let recorder = Recorder()
        let entry = makeTestEntry(name: "a.txt")
        let service = MockTrashService(trashImpl: { urls in
            recorder.trashedURLs = urls
            return OperationResult(success: true, errorMessage: nil, processedCount: 1, failedItems: [])
        })
        let viewModel = DeleteConfirmDialogViewModel(trashService: service, entries: [entry])

        await viewModel.confirm()

        #expect(recorder.trashedURLs == [entry.path])
        #expect(viewModel.result?.success == true)
        #expect(viewModel.isCompleted)
        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - multiple files (FO-13)

    @Test("confirm with multiple files trashes all of them")
    func confirmMultipleFilesTrashesAll() async {
        final class Recorder { var trashedURLs: [URL]? }
        let recorder = Recorder()
        let entries = [makeTestEntry(name: "a.txt"), makeTestEntry(name: "b.txt")]
        let service = MockTrashService(trashImpl: { urls in
            recorder.trashedURLs = urls
            return OperationResult(success: true, errorMessage: nil, processedCount: urls.count, failedItems: [])
        })
        let viewModel = DeleteConfirmDialogViewModel(trashService: service, entries: entries)

        await viewModel.confirm()

        #expect(recorder.trashedURLs == entries.map(\.path))
        #expect(viewModel.result?.processedCount == 2)
        #expect(viewModel.isCompleted)
    }

    // MARK: - empty selection guard

    @Test("confirm with an empty selection sets an error and does not call TrashService")
    func confirmEmptySelectionIsGuarded() async {
        final class Recorder { var callCount = 0 }
        let recorder = Recorder()
        let service = MockTrashService(trashImpl: { urls in
            recorder.callCount += 1
            return OperationResult(success: true, errorMessage: nil, processedCount: urls.count, failedItems: [])
        })
        let viewModel = DeleteConfirmDialogViewModel(trashService: service, entries: [])

        await viewModel.confirm()

        #expect(recorder.callCount == 0)
        #expect(viewModel.isCompleted == false)
        #expect(viewModel.errorMessage == "No files selected.")
        #expect(viewModel.result == nil)
    }

    // MARK: - count

    @Test("count reflects the number of entries")
    func countReflectsEntries() {
        let entries = [makeTestEntry(name: "a.txt"), makeTestEntry(name: "b.txt"), makeTestEntry(name: "c.txt")]
        let viewModel = DeleteConfirmDialogViewModel(trashService: MockTrashService(), entries: entries)

        #expect(viewModel.count == 3)
    }
}

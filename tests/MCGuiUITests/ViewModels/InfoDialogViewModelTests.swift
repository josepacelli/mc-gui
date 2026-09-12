import Foundation
import Testing
@testable import MCGuiUI
import MCGuiCore

@Suite("InfoDialogViewModel")
@MainActor
struct InfoDialogViewModelTests {

    @Test("for a file entry, totalSize is set immediately from entry.size and itemCount stays nil")
    func fileEntryUsesStaticSizeImmediately() {
        let file = makeTestEntry(name: "notes.txt", size: 42, type: .file)
        let viewModel = InfoDialogViewModel(entry: file, fileSystemService: MockFileSystemService())

        #expect(viewModel.totalSize == 42)
        #expect(viewModel.itemCount == nil)
    }

    @Test("for a folder entry, totalSize and itemCount stay nil until startSizeCalculationIfNeeded completes")
    func folderEntryStaysNilUntilCalculated() async {
        let folder = makeTestEntry(name: "folder", type: .directory)
        let fileA = makeTestEntry(name: "a.txt", size: 10)
        let fileB = makeTestEntry(name: "b.txt", size: 20)
        let service = MockFileSystemService(listDirectoryImpl: { url in
            url == folder.path ? [fileA, fileB] : []
        })
        let viewModel = InfoDialogViewModel(entry: folder, fileSystemService: service)

        #expect(viewModel.totalSize == nil)
        #expect(viewModel.itemCount == nil)

        await viewModel.startSizeCalculationIfNeeded()

        #expect(viewModel.totalSize == 30)
        #expect(viewModel.itemCount == 2)
    }

    @Test("an empty folder resolves to 0 bytes and 0 items rather than staying uncalculated")
    func emptyFolderResolvesToZero() async {
        let folder = makeTestEntry(name: "empty", type: .directory)
        let service = MockFileSystemService(listDirectoryImpl: { _ in [] })
        let viewModel = InfoDialogViewModel(entry: folder, fileSystemService: service)

        await viewModel.startSizeCalculationIfNeeded()

        #expect(viewModel.totalSize == 0)
        #expect(viewModel.itemCount == 0)
    }

    @Test("recursive size and item count include files and subfolders nested at every level")
    func nestedSubfoldersSumEveryLevel() async {
        let root = makeTestEntry(name: "root", type: .directory)
        let sub = makeTestEntry(name: "sub", type: .directory)
        let fileInRoot = makeTestEntry(name: "top.txt", size: 5)
        let fileInSub = makeTestEntry(name: "nested.txt", size: 7)
        let service = MockFileSystemService(listDirectoryImpl: { url in
            if url == root.path { return [fileInRoot, sub] }
            if url == sub.path { return [fileInSub] }
            return []
        })
        let viewModel = InfoDialogViewModel(entry: root, fileSystemService: service)

        await viewModel.startSizeCalculationIfNeeded()

        #expect(viewModel.totalSize == 12)
        #expect(viewModel.itemCount == 3)
    }

    @Test("cancelling the calculation task leaves totalSize and itemCount nil, without crashing")
    func cancellationStopsAccumulationWithoutCrashing() async {
        let root = makeTestEntry(name: "root", type: .directory)
        let sub = makeTestEntry(name: "sub", type: .directory)
        let fileInSub = makeTestEntry(name: "nested.txt", size: 7)

        final class TaskBox { var task: Task<Void, Never>? }
        let box = TaskBox()

        let service = MockFileSystemService(listDirectoryImpl: { url in
            if url == root.path { return [sub] }
            if url == sub.path {
                box.task?.cancel()
                return [fileInSub]
            }
            return []
        })
        let viewModel = InfoDialogViewModel(entry: root, fileSystemService: service)

        let task = Task { await viewModel.startSizeCalculationIfNeeded() }
        box.task = task
        await task.value

        #expect(viewModel.totalSize == nil)
        #expect(viewModel.itemCount == nil)
    }
}

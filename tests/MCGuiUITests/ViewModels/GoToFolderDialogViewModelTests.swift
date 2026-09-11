import Foundation
import Testing
@testable import MCGuiUI
import MCGuiCore

private func makeDirEntry(name: String, path: String) -> FileEntry {
    FileEntry(
        name: name,
        path: URL(fileURLWithPath: path),
        size: 0,
        creationDate: Date(timeIntervalSince1970: 0),
        modificationDate: Date(timeIntervalSince1970: 0),
        permissions: [],
        type: .directory,
        isHidden: false,
        isSymlink: false,
        symlinkTarget: nil
    )
}

@Suite("GoToFolderDialogViewModel")
@MainActor
struct GoToFolderDialogViewModelTests {

    @Test("path defaults to the current directory")
    func pathDefaultsToCurrentDirectory() {
        let viewModel = GoToFolderDialogViewModel(fileSystemService: MockFileSystemService(), currentPath: URL(fileURLWithPath: "/tmp"))

        #expect(viewModel.path == "/tmp")
    }

    @Test("confirming a valid, existing directory completes with the resolved path")
    func validDirectoryCompletes() async {
        let service = MockFileSystemService(listDirectoryImpl: { _ in [] })
        let viewModel = GoToFolderDialogViewModel(fileSystemService: service, currentPath: URL(fileURLWithPath: "/tmp"))
        viewModel.path = "/var"

        await viewModel.confirm()

        #expect(viewModel.isCompleted)
        #expect(viewModel.resultPath == URL(fileURLWithPath: "/var"))
        #expect(viewModel.errorMessage == nil)
    }

    @Test("confirming an empty path is rejected without completing")
    func emptyPathIsRejected() async {
        let viewModel = GoToFolderDialogViewModel(fileSystemService: MockFileSystemService(), currentPath: URL(fileURLWithPath: "/tmp"))
        viewModel.path = "   "

        await viewModel.confirm()

        #expect(viewModel.isCompleted == false)
        #expect(viewModel.errorMessage != nil)
    }

    @Test("confirming a path the filesystem rejects surfaces the error and does not complete")
    func nonexistentDirectorySurfacesError() async {
        let service = MockFileSystemService(listDirectoryImpl: { _ in throw MockError(message: "No such directory") })
        let viewModel = GoToFolderDialogViewModel(fileSystemService: service, currentPath: URL(fileURLWithPath: "/tmp"))
        viewModel.path = "/does/not/exist"

        await viewModel.confirm()

        #expect(viewModel.isCompleted == false)
        #expect(viewModel.errorMessage == "No such directory")
    }

    @Test("expandToCurrentPath expands and loads every ancestor down to the current directory")
    func expandToCurrentPathExpandsAncestors() async {
        let service = MockFileSystemService(listDirectoryImpl: { url in
            switch url.path {
            case "/": return [makeDirEntry(name: "Users", path: "/Users")]
            case "/Users": return [makeDirEntry(name: "pacelli", path: "/Users/pacelli")]
            case "/Users/pacelli": return []
            default: return []
            }
        })
        let viewModel = GoToFolderDialogViewModel(fileSystemService: service, currentPath: URL(fileURLWithPath: "/Users/pacelli"))

        let revealed = await viewModel.expandToCurrentPath()

        #expect(revealed == URL(fileURLWithPath: "/Users/pacelli"))
        #expect(viewModel.root.isExpanded)
        let usersNode = viewModel.root.child(at: URL(fileURLWithPath: "/Users"))
        #expect(usersNode?.isExpanded == true)
        let pacelliNode = usersNode?.child(at: URL(fileURLWithPath: "/Users/pacelli"))
        #expect(pacelliNode?.isExpanded == true)
    }

    @Test("selecting a tree node updates the path field")
    func selectingNodeUpdatesPath() {
        let viewModel = GoToFolderDialogViewModel(fileSystemService: MockFileSystemService(), currentPath: URL(fileURLWithPath: "/tmp"))

        viewModel.selectNode(URL(fileURLWithPath: "/Users/pacelli"))

        #expect(viewModel.path == "/Users/pacelli")
        #expect(viewModel.selectedURL == URL(fileURLWithPath: "/Users/pacelli"))
    }
}

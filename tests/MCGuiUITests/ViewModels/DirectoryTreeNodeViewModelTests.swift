import Foundation
import Testing
@testable import MCGuiUI
import MCGuiCore

@Suite("DirectoryTreeNodeViewModel")
@MainActor
struct DirectoryTreeNodeViewModelTests {

    @Test("children start unloaded")
    func childrenStartUnloaded() {
        let node = DirectoryTreeNodeViewModel(url: URL(fileURLWithPath: "/tmp"), fileSystemService: MockFileSystemService())

        #expect(node.children == nil)
    }

    @Test("loading children filters out files and hidden directories, sorted by name")
    func loadingChildrenFiltersAndSorts() async {
        let service = MockFileSystemService(listDirectoryImpl: { _ in
            [
                makeTestEntry(name: "zebra", type: .directory),
                makeTestEntry(name: "apple", type: .directory),
                makeTestEntry(name: "notes.txt", type: .file),
                makeTestEntry(name: ".hidden", type: .directory, isHidden: true)
            ]
        })
        let node = DirectoryTreeNodeViewModel(url: URL(fileURLWithPath: "/tmp"), fileSystemService: service)

        await node.loadChildrenIfNeeded()

        #expect(node.children?.map(\.name) == ["apple", "zebra"])
    }

    @Test("loading children a second time does not re-fetch")
    func loadingChildrenIsIdempotent() async {
        final class Recorder { var callCount = 0 }
        let recorder = Recorder()
        let service = MockFileSystemService(listDirectoryImpl: { _ in
            recorder.callCount += 1
            return []
        })
        let node = DirectoryTreeNodeViewModel(url: URL(fileURLWithPath: "/tmp"), fileSystemService: service)

        await node.loadChildrenIfNeeded()
        await node.loadChildrenIfNeeded()

        #expect(recorder.callCount == 1)
    }

    @Test("a filesystem failure results in an empty children list instead of leaving it unloaded")
    func failureResultsInEmptyChildren() async {
        let service = MockFileSystemService(listDirectoryImpl: { _ in throw MockError(message: "Permission denied") })
        let node = DirectoryTreeNodeViewModel(url: URL(fileURLWithPath: "/root"), fileSystemService: service)

        await node.loadChildrenIfNeeded()

        #expect(node.children?.isEmpty == true)
    }
}

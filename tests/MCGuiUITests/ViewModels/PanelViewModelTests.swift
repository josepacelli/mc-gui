import Foundation
import Testing
@testable import MCGuiUI
import MCGuiCore

@Suite("PanelViewModel")
@MainActor
struct PanelViewModelTests {

    // MARK: - load success / failure (FS-03, FS-08)

    @Test("load success populates entries, clears error, and stops loading")
    func loadSuccessPopulatesEntries() async {
        let entries = [makeTestEntry(name: "a.txt"), makeTestEntry(name: "b.txt")]
        let service = MockFileSystemService { _ in entries }
        let viewModel = PanelViewModel(fileSystemService: service, initialPath: URL(fileURLWithPath: "/tmp"))

        await viewModel.load()

        #expect(viewModel.entries.count == 2)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isLoading == false)
    }

    @Test("load failure sets errorMessage to the failure reason and stops loading")
    func loadFailureSetsErrorMessage() async {
        let service = MockFileSystemService { _ in throw MockError(message: "Permission denied") }
        let viewModel = PanelViewModel(fileSystemService: service, initialPath: URL(fileURLWithPath: "/tmp"))

        await viewModel.load()

        #expect(viewModel.errorMessage == "Permission denied")
        #expect(viewModel.isLoading == false)
    }

    @Test("load with an explicit path updates currentPath (FS-04/FS-05 navigation)")
    func loadWithExplicitPathUpdatesCurrentPath() async {
        let service = MockFileSystemService { _ in [] }
        let viewModel = PanelViewModel(fileSystemService: service, initialPath: URL(fileURLWithPath: "/tmp"))
        let target = URL(fileURLWithPath: "/tmp/sub")

        await viewModel.load(target)

        #expect(viewModel.currentPath == target)
    }

    @Test("isLoading is true while the load is in flight and false once it completes (FS-07)")
    func isLoadingReflectsInFlightState() async {
        let service = MockFileSystemService { _ in
            try await Task.sleep(nanoseconds: 50_000_000)
            return []
        }
        let viewModel = PanelViewModel(fileSystemService: service, initialPath: URL(fileURLWithPath: "/tmp"))

        #expect(viewModel.isLoading == false)
        let loadTask = Task { await viewModel.load() }
        try? await Task.sleep(nanoseconds: 10_000_000)
        #expect(viewModel.isLoading == true)

        await loadTask.value
        #expect(viewModel.isLoading == false)
    }

    // MARK: - sort (FS-09)

    @Test("sort by name ascending and descending")
    func sortByNameBothDirections() async {
        let entries = [makeTestEntry(name: "banana"), makeTestEntry(name: "apple"), makeTestEntry(name: "cherry")]
        let service = MockFileSystemService { _ in entries }
        let viewModel = PanelViewModel(fileSystemService: service, initialPath: URL(fileURLWithPath: "/tmp"))
        await viewModel.load()

        viewModel.sortColumn = .name
        viewModel.sortAscending = true
        #expect(viewModel.entries.map(\.name) == ["apple", "banana", "cherry"])

        viewModel.sortAscending = false
        #expect(viewModel.entries.map(\.name) == ["cherry", "banana", "apple"])
    }

    @Test("sort by size ascending and descending")
    func sortBySizeBothDirections() async {
        let entries = [makeTestEntry(name: "a", size: 30), makeTestEntry(name: "b", size: 10), makeTestEntry(name: "c", size: 20)]
        let service = MockFileSystemService { _ in entries }
        let viewModel = PanelViewModel(fileSystemService: service, initialPath: URL(fileURLWithPath: "/tmp"))
        await viewModel.load()

        viewModel.sortColumn = .size
        viewModel.sortAscending = true
        #expect(viewModel.entries.map(\.size) == [10, 20, 30])

        viewModel.sortAscending = false
        #expect(viewModel.entries.map(\.size) == [30, 20, 10])
    }

    @Test("sort by date ascending and descending")
    func sortByDateBothDirections() async {
        let d1 = Date(timeIntervalSince1970: 100)
        let d2 = Date(timeIntervalSince1970: 200)
        let d3 = Date(timeIntervalSince1970: 300)
        let entries = [makeTestEntry(name: "a", date: d3), makeTestEntry(name: "b", date: d1), makeTestEntry(name: "c", date: d2)]
        let service = MockFileSystemService { _ in entries }
        let viewModel = PanelViewModel(fileSystemService: service, initialPath: URL(fileURLWithPath: "/tmp"))
        await viewModel.load()

        viewModel.sortColumn = .date
        viewModel.sortAscending = true
        #expect(viewModel.entries.map(\.name) == ["b", "c", "a"])

        viewModel.sortAscending = false
        #expect(viewModel.entries.map(\.name) == ["a", "c", "b"])
    }

    @Test("sort by type ascending and descending")
    func sortByTypeBothDirections() async {
        let entries = [
            makeTestEntry(name: "f", type: .file),
            makeTestEntry(name: "d", type: .directory),
            makeTestEntry(name: "s", type: .symlink)
        ]
        let service = MockFileSystemService { _ in entries }
        let viewModel = PanelViewModel(fileSystemService: service, initialPath: URL(fileURLWithPath: "/tmp"))
        await viewModel.load()

        viewModel.sortColumn = .type
        viewModel.sortAscending = true
        #expect(viewModel.entries.map(\.name) == ["d", "f", "s"])

        viewModel.sortAscending = false
        #expect(viewModel.entries.map(\.name) == ["s", "f", "d"])
    }

    // MARK: - hidden-files toggle (FS-10)

    @Test("showHidden false filters out hidden entries")
    func showHiddenFalseFiltersHiddenEntries() async {
        let entries = [makeTestEntry(name: "visible", isHidden: false), makeTestEntry(name: ".hidden", isHidden: true)]
        let service = MockFileSystemService { _ in entries }
        let viewModel = PanelViewModel(fileSystemService: service, initialPath: URL(fileURLWithPath: "/tmp"))
        viewModel.showHidden = false

        await viewModel.load()

        #expect(viewModel.entries.map(\.name) == ["visible"])
    }

    @Test("showHidden true includes hidden entries")
    func showHiddenTrueIncludesHiddenEntries() async {
        let entries = [makeTestEntry(name: "visible", isHidden: false), makeTestEntry(name: ".hidden", isHidden: true)]
        let service = MockFileSystemService { _ in entries }
        let viewModel = PanelViewModel(fileSystemService: service, initialPath: URL(fileURLWithPath: "/tmp"))
        viewModel.showHidden = true

        await viewModel.load()

        #expect(Set(viewModel.entries.map(\.name)) == Set(["visible", ".hidden"]))
    }
}

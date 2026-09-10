import Foundation
import Testing
@testable import MCGuiUI

/// Unit tests for `BookmarksViewModel`, the `@Observable` state `BookmarksView` extracts
/// for bookmark add/list/remove (BM-01, BM-02 data, BM-04, T54). `BookmarksView.body`
/// itself (the Cmd+D button, row rendering, remove control) is thin declarative glue with
/// no additional testable logic - consistent with the Phase 4/9/12 view precedent, it has
/// no XCUITest coverage yet (no Xcode project/scheme exists in this pure-SPM setup).
@Suite("BookmarksViewModel")
@MainActor
struct BookmarksViewModelTests {

    // MARK: - refresh (BM-02 data)

    @Test("refresh populates bookmarks from the injected list action")
    func refreshPopulatesBookmarks() async {
        let entry = BookmarkEntry(name: "Projects", path: URL(fileURLWithPath: "/tmp/projects"))
        let actions = BookmarksActions(list: { [entry] })
        let viewModel = BookmarksViewModel(actions: actions)

        await viewModel.refresh()

        #expect(viewModel.bookmarks == [entry])
        #expect(viewModel.errorMessage == nil)
    }

    @Test("refresh sets errorMessage when the list action throws")
    func refreshSetsErrorMessageOnFailure() async {
        let actions = BookmarksActions(list: { throw MockError(message: "disk error") })
        let viewModel = BookmarksViewModel(actions: actions)

        await viewModel.refresh()

        #expect(viewModel.errorMessage == "disk error")
    }

    // MARK: - addBookmark (BM-01)

    @Test("addBookmark builds an entry named after the directory's last path component")
    func addBookmarkBuildsEntryFromDirectory() async {
        let box = BookmarksBox(entries: [])
        let actions = BookmarksActions(
            list: { box.entries },
            add: { entry in box.entries.append(entry) }
        )
        let viewModel = BookmarksViewModel(actions: actions)
        let directory = URL(fileURLWithPath: "/tmp/my-project")

        await viewModel.addBookmark(for: directory)

        #expect(viewModel.bookmarks.map(\.name) == ["my-project"])
        #expect(viewModel.bookmarks.map(\.path) == [directory])
    }

    @Test("addBookmark refreshes the list after adding, reflecting the persisted state")
    func addBookmarkRefreshesAfterAdding() async {
        let box = BookmarksBox(entries: [])
        let actions = BookmarksActions(
            list: { box.entries },
            add: { entry in box.entries.append(entry) }
        )
        let viewModel = BookmarksViewModel(actions: actions)

        await viewModel.addBookmark(for: URL(fileURLWithPath: "/tmp/a"))
        await viewModel.addBookmark(for: URL(fileURLWithPath: "/tmp/b"))

        #expect(viewModel.bookmarks.count == 2)
    }

    @Test("addBookmark sets errorMessage when the add action throws")
    func addBookmarkSetsErrorMessageOnFailure() async {
        let actions = BookmarksActions(add: { _ in throw MockError(message: "disk full") })
        let viewModel = BookmarksViewModel(actions: actions)

        await viewModel.addBookmark(for: URL(fileURLWithPath: "/tmp/a"))

        #expect(viewModel.errorMessage == "disk full")
    }

    // MARK: - remove (BM-04)

    @Test("remove deletes the bookmark with the given id and refreshes the list")
    func removeDeletesBookmarkAndRefreshes() async {
        let toRemove = BookmarkEntry(name: "Downloads", path: URL(fileURLWithPath: "/tmp/downloads"))
        let toKeep = BookmarkEntry(name: "Projects", path: URL(fileURLWithPath: "/tmp/projects"))
        let box = BookmarksBox(entries: [toRemove, toKeep])
        let actions = BookmarksActions(
            list: { box.entries },
            remove: { id in box.entries.removeAll { $0.id == id } }
        )
        let viewModel = BookmarksViewModel(actions: actions)
        await viewModel.refresh()

        await viewModel.remove(id: toRemove.id)

        #expect(viewModel.bookmarks == [toKeep])
    }

    @Test("remove sets errorMessage when the remove action throws")
    func removeSetsErrorMessageOnFailure() async {
        let actions = BookmarksActions(remove: { _ in throw MockError(message: "permission denied") })
        let viewModel = BookmarksViewModel(actions: actions)

        await viewModel.remove(id: UUID())

        #expect(viewModel.errorMessage == "permission denied")
    }
}

/// A mutable box so tests can simulate a backing store's state changing across separate
/// `list`/`add`/`remove` closure calls (mirrors `VolumesBox` in `MainWindowVolumesTests`).
private final class BookmarksBox {
    var entries: [BookmarkEntry]
    init(entries: [BookmarkEntry]) { self.entries = entries }
}

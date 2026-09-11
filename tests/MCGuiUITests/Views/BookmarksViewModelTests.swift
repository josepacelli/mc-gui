import Foundation
import Testing
@testable import MCGuiUI

@Suite("BookmarksViewModel")
@MainActor
struct BookmarksViewModelTests {


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

private final class BookmarksBox {
    var entries: [BookmarkEntry]
    init(entries: [BookmarkEntry]) { self.entries = entries }
}

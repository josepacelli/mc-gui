import Foundation
import Testing
@testable import MCGuiUI

/// Unit tests for `UserMenuViewModel`, the `@Observable` state `UserMenuView` extracts
/// for item add/list/remove/run (F2). `UserMenuView.body` itself is thin declarative
/// glue with no additional testable logic - matches `BookmarksViewModelTests`' precedent.
@Suite("UserMenuViewModel")
@MainActor
struct UserMenuViewModelTests {

    private let context = UserMenuContext(
        currentFile: URL(fileURLWithPath: "/tmp/a.txt"),
        currentDir: URL(fileURLWithPath: "/tmp/left"),
        otherDir: URL(fileURLWithPath: "/tmp/right")
    )

    // MARK: - refresh

    @Test("refresh populates items from the injected list action")
    func refreshPopulatesItems() async {
        let entry = UserMenuEntry(label: "Git Status", command: "git status %d")
        let actions = UserMenuActions(list: { [entry] })
        let viewModel = UserMenuViewModel(actions: actions)

        await viewModel.refresh()

        #expect(viewModel.items == [entry])
        #expect(viewModel.errorMessage == nil)
    }

    @Test("refresh sets errorMessage when the list action throws")
    func refreshSetsErrorMessageOnFailure() async {
        let actions = UserMenuActions(list: { throw MockError(message: "disk error") })
        let viewModel = UserMenuViewModel(actions: actions)

        await viewModel.refresh()

        #expect(viewModel.errorMessage == "disk error")
    }

    // MARK: - addItem

    @Test("addItem with a non-empty label and command adds and refreshes")
    func addItemAddsAndRefreshes() async {
        let box = UserMenuBox(entries: [])
        let actions = UserMenuActions(
            list: { box.entries },
            add: { entry in box.entries.append(entry) }
        )
        let viewModel = UserMenuViewModel(actions: actions)

        await viewModel.addItem(label: "Git Status", command: "git status %d")

        #expect(viewModel.items.map(\.label) == ["Git Status"])
        #expect(viewModel.items.map(\.command) == ["git status %d"])
    }

    @Test("addItem with an empty label is a no-op")
    func addItemEmptyLabelIsNoOp() async {
        let box = UserMenuBox(entries: [])
        let actions = UserMenuActions(
            list: { box.entries },
            add: { entry in box.entries.append(entry) }
        )
        let viewModel = UserMenuViewModel(actions: actions)

        await viewModel.addItem(label: "", command: "echo hi")

        #expect(viewModel.items.isEmpty)
    }

    @Test("addItem with an empty command is a no-op")
    func addItemEmptyCommandIsNoOp() async {
        let box = UserMenuBox(entries: [])
        let actions = UserMenuActions(
            list: { box.entries },
            add: { entry in box.entries.append(entry) }
        )
        let viewModel = UserMenuViewModel(actions: actions)

        await viewModel.addItem(label: "Git Status", command: "")

        #expect(viewModel.items.isEmpty)
    }

    @Test("addItem sets errorMessage when the add action throws")
    func addItemSetsErrorMessageOnFailure() async {
        let actions = UserMenuActions(add: { _ in throw MockError(message: "disk full") })
        let viewModel = UserMenuViewModel(actions: actions)

        await viewModel.addItem(label: "Git Status", command: "git status %d")

        #expect(viewModel.errorMessage == "disk full")
    }

    // MARK: - remove

    @Test("remove deletes the item with the given id and refreshes the list")
    func removeDeletesItemAndRefreshes() async {
        let toRemove = UserMenuEntry(label: "Open in Finder", command: "open %d")
        let toKeep = UserMenuEntry(label: "Git Status", command: "git status %d")
        let box = UserMenuBox(entries: [toRemove, toKeep])
        let actions = UserMenuActions(
            list: { box.entries },
            remove: { id in box.entries.removeAll { $0.id == id } }
        )
        let viewModel = UserMenuViewModel(actions: actions)
        await viewModel.refresh()

        await viewModel.remove(id: toRemove.id)

        #expect(viewModel.items == [toKeep])
    }

    @Test("remove sets errorMessage when the remove action throws")
    func removeSetsErrorMessageOnFailure() async {
        let actions = UserMenuActions(remove: { _ in throw MockError(message: "permission denied") })
        let viewModel = UserMenuViewModel(actions: actions)

        await viewModel.remove(id: UUID())

        #expect(viewModel.errorMessage == "permission denied")
    }

    // MARK: - run

    @Test("run records the result and passes the context through to the run action")
    func runRecordsResultAndPassesContext() async {
        let entry = UserMenuEntry(label: "Git Status", command: "git status %d")
        var receivedContext: UserMenuContext?
        let actions = UserMenuActions(run: { _, context in
            receivedContext = context
            return UserMenuRunResult(output: "clean", exitCode: 0)
        })
        let viewModel = UserMenuViewModel(actions: actions)

        await viewModel.run(entry, context: context)

        #expect(viewModel.lastResult == UserMenuRunResult(output: "clean", exitCode: 0))
        #expect(receivedContext == context)
        #expect(viewModel.isRunning == false)
    }
}

/// A mutable box so tests can simulate a backing store's state changing across separate
/// `list`/`add`/`remove` closure calls (mirrors `BookmarksBox`).
private final class UserMenuBox {
    var entries: [UserMenuEntry]
    init(entries: [UserMenuEntry]) { self.entries = entries }
}

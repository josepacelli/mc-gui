import SwiftUI
import AppKit
import MCGuiCore
import MCGuiUI
import MCGuiMacOS

/// The app's entry point (SWIFT-05, MB-01): wires `MainWindowViewModel`, `WindowManager`,
/// and `AppCommands` together so `swift run` launches a visible dual-pane window with a
/// full native menu bar. Replaces the placeholder `main.swift`.
///
/// Uses `Settings {}` as the app's only `Scene` - the main/viewer/editor windows are
/// created and shown imperatively by `WindowManager` (T49), not by SwiftUI's scene-based
/// window system, so no `WindowGroup` is needed. `.commandsRemoved()` strips SwiftUI's own
/// default File/Edit/View/Window/Help menu contributions before `AppCommands` (T48) adds
/// its own - without it, those defaults and `AppCommands`' identically-named menus would
/// appear side by side as duplicates.
@main
struct AppEntry: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commandsRemoved()
        .commands {
            AppCommands(actions: appDelegate.commandActions)
        }
    }
}

/// Owns the `WindowManager` and `MainWindowViewModel` for the app's lifetime, shows the
/// main window on launch, and builds the `AppCommandActions` closures `AppCommands`
/// routes menu selections through.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let windowManager = WindowManager()
    private let mainViewModel: MainWindowViewModel
    private let bookmarksViewModel: BookmarksViewModel

    override init() {
        let fileSystemService = FileSystemServiceImpl()
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        mainViewModel = MainWindowViewModel(
            fileSystemService: fileSystemService,
            leftInitialPath: homeDirectory,
            rightInitialPath: homeDirectory
        )
        // BM-01..04: bridges MCGuiUI's BookmarksView/BookmarksViewModel (which cannot
        // depend on MCGuiMacOS) to the real, disk-persisted BookmarkStore - mirrors
        // onViewFile/onEditFile's ViewerService/EditorService bridge below.
        let bookmarkStore = BookmarkStore()
        bookmarksViewModel = BookmarksViewModel(actions: BookmarksActions(
            list: { try await bookmarkStore.list().map { BookmarkEntry(id: $0.id, name: $0.name, path: $0.path) } },
            add: { entry in try await bookmarkStore.add(Bookmark(id: entry.id, name: entry.name, path: entry.path)) },
            remove: { id in try await bookmarkStore.remove(id: id) }
        ))
        super.init()
    }

    /// Menu actions that meaningfully operate on the active panel today (sort, hidden
    /// toggle, refresh, parent/home/computer/back/forward navigation) are wired for real.
    /// `view`/`edit`/`copy`/`move`/`mkdir`/`delete` stay no-op here: triggering them from
    /// the native menu bar would need the active panel's current selection, which lives in
    /// `PanelView`'s private `@State` (T21/T33) with no accessor exposed upward - lifting
    /// that state is a larger change out of scope. The physical F3-F8 keys already work
    /// correctly via `PanelView`'s own `.onKeyPress` handling (T33 for F5-F8, T50 for
    /// F3/F4), and classic-layout-parity's `TopBar`/`ButtonBar` also reach them via
    /// `PanelAction`/`pendingAction` (state that lives on `MainWindow`, not reachable from
    /// here either); these native menu items are secondary/redundant triggers for the same
    /// shortcuts and inherit this limitation until selection state is lifted to
    /// `MainWindowViewModel`.
    var commandActions: AppCommandActions {
        AppCommandActions(
            sortByName: { [mainViewModel] in mainViewModel.activePanelViewModel.sortColumn = .name },
            sortBySize: { [mainViewModel] in mainViewModel.activePanelViewModel.sortColumn = .size },
            sortByDate: { [mainViewModel] in mainViewModel.activePanelViewModel.sortColumn = .date },
            sortByType: { [mainViewModel] in mainViewModel.activePanelViewModel.sortColumn = .type },
            toggleHiddenFiles: { [mainViewModel] in mainViewModel.activePanelViewModel.showHidden.toggle() },
            refresh: { [mainViewModel] in
                Task { await mainViewModel.activePanelViewModel.load() }
            },
            navigateToParent: { [mainViewModel] in
                let parent = mainViewModel.activePanelViewModel.currentPath.deletingLastPathComponent()
                Task { await mainViewModel.activePanelViewModel.load(parent) }
            },
            goBack: { [mainViewModel] in
                Task { await mainViewModel.activePanelViewModel.goBack() }
            },
            goForward: { [mainViewModel] in
                Task { await mainViewModel.activePanelViewModel.goForward() }
            },
            goHome: { [mainViewModel] in
                Task { await mainViewModel.activePanelViewModel.load(FileManager.default.homeDirectoryForCurrentUser) }
            },
            goComputer: { [mainViewModel] in
                Task { await mainViewModel.activePanelViewModel.load(URL(fileURLWithPath: "/")) }
            },
            showViewerWindow: { [windowManager] in windowManager.bringViewerToFront() },
            showEditorWindow: { [windowManager] in windowManager.bringEditorToFront() }
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        windowManager.showMainWindow(
            viewModel: mainViewModel,
            onViewFile: { [windowManager] entry, side in windowManager.showViewer(for: entry, panel: side) },
            onEditFile: { [windowManager] entry, _ in windowManager.showEditor(for: entry) },
            bookmarksViewModel: bookmarksViewModel
        )
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

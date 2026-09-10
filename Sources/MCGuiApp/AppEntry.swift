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

    override init() {
        let fileSystemService = FileSystemServiceImpl()
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        mainViewModel = MainWindowViewModel(
            fileSystemService: fileSystemService,
            leftInitialPath: homeDirectory,
            rightInitialPath: homeDirectory
        )
        super.init()
    }

    /// Menu actions that meaningfully operate on the active panel today (sort, hidden
    /// toggle, refresh, parent/home/computer navigation) are wired for real. `goBack`/
    /// `goForward` stay no-op: back/forward history (`PathHistoryManager`, T10) isn't
    /// wired into `PanelViewModel` yet - out of this batch's scope. `view`/`edit`/`copy`/
    /// `move`/`mkdir`/`delete` also stay no-op here: triggering them from the menu bar
    /// would need the active panel's current selection, which lives in `PanelView`'s
    /// private `@State` (T21/T33) with no accessor exposed upward - lifting that state is
    /// a larger change out of scope. The physical F3-F8 keys already work correctly via
    /// `PanelView`'s own `.onKeyPress` handling (T33 for F5-F8, T50 for F3/F4); these menu
    /// items are secondary/redundant triggers for the same shortcuts and inherit this
    /// limitation until selection state is lifted in a future task.
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
            onEditFile: { [windowManager] entry, _ in windowManager.showEditor(for: entry) }
        )
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

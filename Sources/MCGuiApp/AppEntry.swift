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
@MainActor
struct AppEntry: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commandsRemoved()
        .commands {
            // VL-01: reading `appDelegate.volumes` here (not just inside
            // `commandActions`/a nested closure) is what makes this `Scene` rebuild the
            // Go menu when `AppDelegate` (an `@Observable` class) posts a change -
            // SwiftUI's Observation tracking only sees property reads that happen
            // directly inside a tracked `body`.
            AppCommands(actions: appDelegate.commandActions, volumes: appDelegate.volumes)
        }
    }
}

/// Owns the `WindowManager` and `MainWindowViewModel` for the app's lifetime, shows the
/// main window on launch, and builds the `AppCommandActions` closures `AppCommands`
/// routes menu selections through.
@MainActor
@Observable
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let windowManager = WindowManager()
    private let mainViewModel: MainWindowViewModel
    private let bookmarksViewModel: BookmarksViewModel
    private let userMenuViewModel: UserMenuViewModel
    // VL-01, VL-04: the native Go menu's volume list, refreshed on mount/unmount -
    // mirrors `MainWindow`'s own `VolumesListViewModel`, duplicated here because this
    // class (not a View) has no access to that one's `@State` instance.
    private(set) var volumes: [VolumeInfo] = []

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
        // F2: same bridging pattern as Bookmarks above, plus `run` shelling out via
        // UserMenuRunner (MCGuiMacOS) - MCGuiUI never touches Process directly.
        let userMenuStore = UserMenuStore()
        userMenuViewModel = UserMenuViewModel(actions: UserMenuActions(
            list: { try await userMenuStore.list().map { UserMenuEntry(id: $0.id, label: $0.label, command: $0.command) } },
            add: { entry in try await userMenuStore.add(UserMenuItem(id: entry.id, label: entry.label, command: entry.command)) },
            remove: { id in try await userMenuStore.remove(id: id) },
            run: { entry, context in
                let result = await UserMenuRunner.run(
                    command: entry.command,
                    currentFile: context.currentFile,
                    currentDir: context.currentDir,
                    otherDir: context.otherDir
                )
                return UserMenuRunResult(output: result.output, exitCode: result.exitCode)
            }
        ))
        super.init()
        volumes = fileSystemService.getVolumes()
        NotificationCenter.default.addObserver(
            self, selector: #selector(refreshVolumes),
            name: NSWorkspace.didMountNotification, object: NSWorkspace.shared
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(refreshVolumes),
            name: NSWorkspace.didUnmountNotification, object: NSWorkspace.shared
        )
    }

    @objc private func refreshVolumes() {
        volumes = mainViewModel.leftPanel.fileSystemService.getVolumes()
    }

    /// Every action here operates on whichever panel is active. Sort/hidden-toggle/
    /// refresh/navigation act directly on `MainWindowViewModel.activePanelViewModel`;
    /// `view`/`edit`/`copy`/`move`/`mkdir`/`delete` route through
    /// `MainWindowViewModel.triggerActivePanel` (`PanelAction`/`pendingAction`, the same
    /// mechanism classic-layout-parity's `TopBar`/`ButtonBar` already use) since those
    /// need the active panel's current selection, which lives in `PanelView`'s private
    /// `@State` - `triggerActivePanel` is the one path that reaches it from outside.
    var commandActions: AppCommandActions {
        AppCommandActions(
            view: { [mainViewModel] in mainViewModel.triggerActivePanel(.view) },
            edit: { [mainViewModel] in mainViewModel.triggerActivePanel(.edit) },
            copy: { [mainViewModel] in mainViewModel.triggerActivePanel(.copy) },
            move: { [mainViewModel] in mainViewModel.triggerActivePanel(.move) },
            mkdir: { [mainViewModel] in mainViewModel.triggerActivePanel(.mkdir) },
            delete: { [mainViewModel] in mainViewModel.triggerActivePanel(.delete) },
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
            goToVolume: { [mainViewModel] volume in
                Task { await mainViewModel.activePanelViewModel.load(volume.mountPoint) }
            },
            showViewerWindow: { [windowManager] in windowManager.bringViewerToFront() },
            showEditorWindow: { [windowManager] in windowManager.bringEditorToFront() },
            showHelp: { [windowManager] in windowManager.showHelp() }
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        windowManager.showMainWindow(
            viewModel: mainViewModel,
            onViewFile: { [windowManager] entry, side in windowManager.showViewer(for: entry, panel: side) },
            onEditFile: { [windowManager] entry, _ in windowManager.showEditor(for: entry) },
            bookmarksViewModel: bookmarksViewModel,
            userMenuViewModel: userMenuViewModel
        )
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

import SwiftUI
import AppKit
import MCGuiCore
import MCGuiUI
import MCGuiMacOS

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
            AppCommands(actions: appDelegate.commandActions, volumes: appDelegate.volumes)
        }
    }
}

@MainActor
@Observable
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let windowManager = WindowManager()
    private let mainViewModel: MainWindowViewModel
    private let bookmarksViewModel: BookmarksViewModel
    private let userMenuViewModel: UserMenuViewModel
    private(set) var volumes: [VolumeInfo] = []

    override init() {
        let fileSystemService = FileSystemServiceImpl()
        let settings = AppSettingsStore.load()
        mainViewModel = MainWindowViewModel(
            fileSystemService: fileSystemService,
            leftInitialPath: settings.leftPath,
            rightInitialPath: settings.rightPath
        )
        mainViewModel.leftPanel.sortColumn = settings.leftSortColumn
        mainViewModel.rightPanel.sortColumn = settings.rightSortColumn
        mainViewModel.leftPanel.showHidden = settings.leftShowHidden
        mainViewModel.rightPanel.showHidden = settings.rightShowHidden
        if settings.activePanel == .right {
            mainViewModel.activate(.right)
        }
        let bookmarkStore = BookmarkStore()
        bookmarksViewModel = BookmarksViewModel(actions: BookmarksActions(
            list: { try await bookmarkStore.list().map { BookmarkEntry(id: $0.id, name: $0.name, path: $0.path) } },
            add: { entry in try await bookmarkStore.add(Bookmark(id: entry.id, name: entry.name, path: entry.path)) },
            remove: { id in try await bookmarkStore.remove(id: id) }
        ))
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

    func applicationWillTerminate(_ notification: Notification) {
        AppSettingsStore.save(mainViewModel)
    }
}

import SwiftUI
import AppKit
import MCGuiCore

@MainActor
@Observable
public final class VolumesListViewModel {
    private let fileSystemService: FileSystemService
    public private(set) var volumes: [VolumeInfo] = []

    public init(fileSystemService: FileSystemService) {
        self.fileSystemService = fileSystemService
        refresh()
    }

    public func refresh() {
        volumes = fileSystemService.getVolumes()
    }
}

@MainActor
public struct MainWindow: View {
    public let viewModel: MainWindowViewModel
    public var onViewFile: (FileEntry, PanelSide) -> Void
    public var onEditFile: (FileEntry, PanelSide) -> Void
    public var onShowProgress: (ProgressDialogViewModel) -> Void
    public var onShowHelp: () -> Void
    public var onShowUserMenu: (UserMenuContext) -> Void
    public let bookmarksViewModel: BookmarksViewModel

    @State private var showBookmarks = false

    @AppStorage(ThemePreference.storageKey) private var themePreference: ThemePreference = .system

    @State private var volumesListViewModel: VolumesListViewModel

    public init(
        viewModel: MainWindowViewModel,
        onViewFile: @escaping (FileEntry, PanelSide) -> Void = { _, _ in },
        onEditFile: @escaping (FileEntry, PanelSide) -> Void = { _, _ in },
        onShowProgress: @escaping (ProgressDialogViewModel) -> Void = { _ in },
        onShowHelp: @escaping () -> Void = {},
        onShowUserMenu: @escaping (UserMenuContext) -> Void = { _ in },
        bookmarksViewModel: BookmarksViewModel
    ) {
        self.viewModel = viewModel
        self.onViewFile = onViewFile
        self.onEditFile = onEditFile
        self.onShowProgress = onShowProgress
        self.onShowHelp = onShowHelp
        self.onShowUserMenu = onShowUserMenu
        self.bookmarksViewModel = bookmarksViewModel
        _volumesListViewModel = State(initialValue: VolumesListViewModel(fileSystemService: viewModel.leftPanel.fileSystemService))
    }

    public var body: some View {
        VStack(spacing: 0) {
            TopBar(
                leftVolumes: volumesListViewModel.volumes,
                rightVolumes: volumesListViewModel.volumes,
                onSelectLeftVolume: { volume in Task { await viewModel.leftPanel.load(volume.mountPoint) } },
                onSelectRightVolume: { volume in Task { await viewModel.rightPanel.load(volume.mountPoint) } },
                onRescanLeft: { Task { await viewModel.leftPanel.load() } },
                onRescanRight: { Task { await viewModel.rightPanel.load() } },
                onFileAction: viewModel.triggerActivePanel,
                onRefreshActive: { Task { await viewModel.activePanelViewModel.load() } },
                onGoBackActive: { Task { await viewModel.activePanelViewModel.goBack() } },
                onGoForwardActive: { Task { await viewModel.activePanelViewModel.goForward() } },
                onToggleHiddenFiles: { viewModel.activePanelViewModel.showHidden.toggle() },
                onOpenBookmarks: { showBookmarks = true }
            )
            .popover(isPresented: $showBookmarks) {
                BookmarksView(
                    viewModel: bookmarksViewModel,
                    activeDirectory: viewModel.activePanelViewModel.currentPath,
                    onNavigate: { path in
                        Task { await viewModel.activePanelViewModel.load(path) }
                        showBookmarks = false
                    }
                )
                .frame(minWidth: 280, minHeight: 240)
            }
            Divider()

            HSplitView {
                PanelView(
                    viewModel: viewModel.leftPanel,
                    isActive: viewModel.activePanel == .left,
                    onActivate: { viewModel.activate(.left) },
                    onViewFile: { entry in onViewFile(entry, .left) },
                    onEditFile: { entry in onEditFile(entry, .left) },
                    onShowProgress: onShowProgress,
                    onHelp: onShowHelp,
                    onUserMenu: onShowUserMenu,
                    pendingAction: Binding(
                        get: { viewModel.leftPendingAction },
                        set: { viewModel.leftPendingAction = $0 }
                    ),
                    otherPanelPath: viewModel.rightPanel.currentPath,
                    onOperationCompleted: { Task { await viewModel.rightPanel.load() } }
                )
                PanelView(
                    viewModel: viewModel.rightPanel,
                    isActive: viewModel.activePanel == .right,
                    onActivate: { viewModel.activate(.right) },
                    onViewFile: { entry in onViewFile(entry, .right) },
                    onEditFile: { entry in onEditFile(entry, .right) },
                    onShowProgress: onShowProgress,
                    onHelp: onShowHelp,
                    onUserMenu: onShowUserMenu,
                    pendingAction: Binding(
                        get: { viewModel.rightPendingAction },
                        set: { viewModel.rightPendingAction = $0 }
                    ),
                    otherPanelPath: viewModel.leftPanel.currentPath,
                    onOperationCompleted: { Task { await viewModel.leftPanel.load() } }
                )
            }

            Divider()
            ButtonBar(onAction: viewModel.triggerActivePanel, onHelp: onShowHelp, onQuit: { NSApp.terminate(nil) })
        }
        .onAppear { volumesListViewModel.refresh() }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didMountNotification)) { _ in
            volumesListViewModel.refresh()
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didUnmountNotification)) { _ in
            volumesListViewModel.refresh()
        }
        .preferredColorScheme(themePreference.colorScheme)
    }
}

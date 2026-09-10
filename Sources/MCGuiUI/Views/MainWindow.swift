import SwiftUI
import AppKit
import MCGuiCore

/// Lists mounted volumes (VL-01, VL-02) via the injected `FileSystemService`, and exposes
/// `refresh()` so `MainWindow` can call it on launch and whenever `NSWorkspace` posts a
/// mount/unmount notification (VL-04). Extracted from `MainWindow`'s view body so the
/// volume-listing logic itself is unit-testable independent of SwiftUI rendering.
@MainActor
@Observable
public final class VolumesListViewModel {
    private let fileSystemService: FileSystemService
    public private(set) var volumes: [VolumeInfo] = []

    public init(fileSystemService: FileSystemService) {
        self.fileSystemService = fileSystemService
        refresh()
    }

    /// Reloads `volumes` from `FileSystemService.getVolumes()`.
    public func refresh() {
        volumes = fileSystemService.getVolumes()
    }
}

/// The root window: a volumes sidebar plus two `PanelView`s side by side in an
/// `HSplitView`, coordinated by a `MainWindowViewModel`.
public struct MainWindow: View {
    public let viewModel: MainWindowViewModel
    // WindowManager gap closure (T50): forwarded from PanelView's own onViewFile/
    // onEditFile, tagged with which side (left/right) triggered it - `WindowManager.
    // showViewer(for:panel:)` needs the panel side to read that panel's file list for
    // Tab/Shift+Tab navigation (FV-05).
    public var onViewFile: (FileEntry, PanelSide) -> Void
    public var onEditFile: (FileEntry, PanelSide) -> Void
    // FO-14: forwarded from PanelView's own onShowProgress (see that type) - presents
    // copy/move progress as an independent, non-modal window instead of a blocking sheet.
    public var onShowProgress: (ProgressDialogViewModel) -> Void
    // BM-01..04: constructed by `MCGuiApp` (real `BookmarkStore`-backed `BookmarksActions`,
    // mirroring the `onViewFile`/`onEditFile` cross-target bridge above) - `MainWindow`
    // only presents it, it never talks to `MCGuiMacOS` directly.
    public let bookmarksViewModel: BookmarksViewModel

    @State private var showBookmarks = false

    // TH-05: reading the same `@AppStorage` key `ThemeMenu` (T47) writes to means this
    // view re-renders immediately whenever the user picks a different theme option, with
    // no direct reference between the two views needed.
    @AppStorage(ThemePreference.storageKey) private var themePreference: ThemePreference = .system

    // classic-layout-parity AD-004/CL-13/CL-14: the former VolumesSidebar is removed to
    // match the original terminal app's layout; `volumesListViewModel` now only feeds the
    // in-window `TopBar`'s Left/Right menus (CL-02).
    @State private var volumesListViewModel: VolumesListViewModel

    public init(
        viewModel: MainWindowViewModel,
        onViewFile: @escaping (FileEntry, PanelSide) -> Void = { _, _ in },
        onEditFile: @escaping (FileEntry, PanelSide) -> Void = { _, _ in },
        onShowProgress: @escaping (ProgressDialogViewModel) -> Void = { _ in },
        bookmarksViewModel: BookmarksViewModel
    ) {
        self.viewModel = viewModel
        self.onViewFile = onViewFile
        self.onEditFile = onEditFile
        self.onShowProgress = onShowProgress
        self.bookmarksViewModel = bookmarksViewModel
        _volumesListViewModel = State(initialValue: VolumesListViewModel(fileSystemService: viewModel.leftPanel.fileSystemService))
    }

    public var body: some View {
        VStack(spacing: 0) {
            // classic-layout-parity CL-01..CL-02: in-window Left|File|Command|Options|Right
            // bar, alongside (not instead of) the native macOS menu bar (AD-004).
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
                    pendingAction: Binding(
                        get: { viewModel.leftPendingAction },
                        set: { viewModel.leftPendingAction = $0 }
                    ),
                    otherPanelPath: viewModel.rightPanel.currentPath
                )
                PanelView(
                    viewModel: viewModel.rightPanel,
                    isActive: viewModel.activePanel == .right,
                    onActivate: { viewModel.activate(.right) },
                    onViewFile: { entry in onViewFile(entry, .right) },
                    onEditFile: { entry in onEditFile(entry, .right) },
                    onShowProgress: onShowProgress,
                    pendingAction: Binding(
                        get: { viewModel.rightPendingAction },
                        set: { viewModel.rightPendingAction = $0 }
                    ),
                    otherPanelPath: viewModel.leftPanel.currentPath
                )
            }

            Divider()
            // classic-layout-parity CL-03..CL-07: bottom F1-F10 button row.
            ButtonBar(onAction: viewModel.triggerActivePanel, onQuit: { NSApp.terminate(nil) })
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

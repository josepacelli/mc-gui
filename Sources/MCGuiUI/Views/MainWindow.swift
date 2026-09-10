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

    // TH-05: reading the same `@AppStorage` key `ThemeMenu` (T47) writes to means this
    // view re-renders immediately whenever the user picks a different theme option, with
    // no direct reference between the two views needed.
    @AppStorage(ThemePreference.storageKey) private var themePreference: ThemePreference = .system

    // SPEC_DEVIATION (T51): VL-01 asks for volumes in "the Go menu" - the app's actual
    // AppKit menu bar Go menu lives in `AppCommands.swift`/`AppEntry.swift` (Phase 11,
    // already-committed, out of this task's `Where` scope: `MainWindow.swift` only). The
    // `Menu("Go")` control below is the quick-access "Go" menu this task's scope can
    // deliver; wiring live volumes into the real menu-bar Go menu is future cross-file
    // work. The sidebar below independently satisfies VL-02's "sidebar or toolbar" wording.
    @State private var volumesListViewModel: VolumesListViewModel

    public init(
        viewModel: MainWindowViewModel,
        onViewFile: @escaping (FileEntry, PanelSide) -> Void = { _, _ in },
        onEditFile: @escaping (FileEntry, PanelSide) -> Void = { _, _ in }
    ) {
        self.viewModel = viewModel
        self.onViewFile = onViewFile
        self.onEditFile = onEditFile
        _volumesListViewModel = State(initialValue: VolumesListViewModel(fileSystemService: viewModel.leftPanel.fileSystemService))
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Menu("Go") {
                    ForEach(volumesListViewModel.volumes) { volume in
                        Button(volume.name) { navigateActivePanel(to: volume) }
                    }
                }
                .disabled(volumesListViewModel.volumes.isEmpty)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            HSplitView {
                VolumesSidebar(viewModel: volumesListViewModel, onSelect: navigateActivePanel)
                    .frame(minWidth: 140, idealWidth: 180, maxWidth: 260)
                PanelView(
                    viewModel: viewModel.leftPanel,
                    isActive: viewModel.activePanel == .left,
                    onActivate: { viewModel.activate(.left) },
                    onViewFile: { entry in onViewFile(entry, .left) },
                    onEditFile: { entry in onEditFile(entry, .left) }
                )
                PanelView(
                    viewModel: viewModel.rightPanel,
                    isActive: viewModel.activePanel == .right,
                    onActivate: { viewModel.activate(.right) },
                    onViewFile: { entry in onViewFile(entry, .right) },
                    onEditFile: { entry in onEditFile(entry, .right) }
                )
            }
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

    /// Navigates the active panel to `volume`'s root (VL-03).
    private func navigateActivePanel(to volume: VolumeInfo) {
        Task { await viewModel.activePanelViewModel.load(volume.mountPoint) }
    }
}

/// Sidebar listing mounted volumes (VL-02); selecting one navigates the active panel to
/// its root (VL-03).
private struct VolumesSidebar: View {
    let viewModel: VolumesListViewModel
    let onSelect: (VolumeInfo) -> Void

    var body: some View {
        List(viewModel.volumes) { volume in
            Button(volume.name) { onSelect(volume) }
                .buttonStyle(.plain)
        }
    }
}

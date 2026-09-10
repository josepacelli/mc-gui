import SwiftUI
import AppKit
import MCGuiCore

/// The classic in-window top menu row (`classic-layout-parity` CL-01..CL-02, STATE.md
/// AD-004): `Left | File | Command | Options | Right`, reproducing the original
/// terminal mc's five top-level menus (`src/filemanager/filemanager.c`'s
/// `menubar_add_menu` calls) alongside - not instead of - the native macOS menu bar
/// (`AppCommands.swift`). Left/Right list that specific panel's mounted volumes and
/// navigate it directly (CL-02), replacing the removed `VolumesSidebar` (CL-13/CL-14).
public struct TopBar: View {
    public var leftVolumes: [VolumeInfo]
    public var rightVolumes: [VolumeInfo]
    public var onSelectLeftVolume: (VolumeInfo) -> Void
    public var onSelectRightVolume: (VolumeInfo) -> Void
    public var onRescanLeft: () -> Void
    public var onRescanRight: () -> Void
    public var onFileAction: (PanelAction) -> Void
    public var onRefreshActive: () -> Void
    public var onGoBackActive: () -> Void
    public var onGoForwardActive: () -> Void
    public var onToggleHiddenFiles: () -> Void
    // BM-01..04: opens the Bookmarks popover (`MainWindow`) - mirrors real mc's Command
    // menu "Directory hotlist" entry (Ctrl+\).
    public var onOpenBookmarks: () -> Void

    public init(
        leftVolumes: [VolumeInfo],
        rightVolumes: [VolumeInfo],
        onSelectLeftVolume: @escaping (VolumeInfo) -> Void,
        onSelectRightVolume: @escaping (VolumeInfo) -> Void,
        onRescanLeft: @escaping () -> Void,
        onRescanRight: @escaping () -> Void,
        onFileAction: @escaping (PanelAction) -> Void,
        onRefreshActive: @escaping () -> Void,
        onGoBackActive: @escaping () -> Void = {},
        onGoForwardActive: @escaping () -> Void = {},
        onToggleHiddenFiles: @escaping () -> Void,
        onOpenBookmarks: @escaping () -> Void = {}
    ) {
        self.leftVolumes = leftVolumes
        self.rightVolumes = rightVolumes
        self.onSelectLeftVolume = onSelectLeftVolume
        self.onSelectRightVolume = onSelectRightVolume
        self.onRescanLeft = onRescanLeft
        self.onRescanRight = onRescanRight
        self.onFileAction = onFileAction
        self.onRefreshActive = onRefreshActive
        self.onGoBackActive = onGoBackActive
        self.onGoForwardActive = onGoForwardActive
        self.onToggleHiddenFiles = onToggleHiddenFiles
        self.onOpenBookmarks = onOpenBookmarks
    }

    public var body: some View {
        HStack(spacing: 14) {
            Menu("Left") {
                ForEach(leftVolumes) { volume in
                    Button(volume.name) { onSelectLeftVolume(volume) }
                }
                if !leftVolumes.isEmpty { Divider() }
                Button("Rescan") { onRescanLeft() }
            }

            Menu("File") {
                Button("New Folder") { onFileAction(.mkdir) }
                Button("Copy") { onFileAction(.copy) }
                Button("Move") { onFileAction(.move) }
                Button("Delete") { onFileAction(.delete) }
                Divider()
                Button("View") { onFileAction(.view) }
                Button("Edit") { onFileAction(.edit) }
                Divider()
                Button("Quit") { NSApp.terminate(nil) }
            }

            Menu("Command") {
                Button("Refresh") { onRefreshActive() }
                Divider()
                // No .keyboardShortcut here - Cmd+[/Cmd+] are already registered by the
                // native macOS menu bar's Go menu (AppCommands.swift); a second
                // registration for the same combo risks an ambiguous/duplicate firing.
                Button("Back") { onGoBackActive() }
                Button("Forward") { onGoForwardActive() }
                Divider()
                Button("Bookmarks…") { onOpenBookmarks() }
            }

            Menu("Options") {
                Button("Show Hidden Files") { onToggleHiddenFiles() }
                Menu("Theme") {
                    ThemeMenu()
                }
            }

            Menu("Right") {
                ForEach(rightVolumes) { volume in
                    Button(volume.name) { onSelectRightVolume(volume) }
                }
                if !rightVolumes.isEmpty { Divider() }
                Button("Rescan") { onRescanRight() }
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

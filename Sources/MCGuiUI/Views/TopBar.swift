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

    // MARK: - localized labels (I18N-01..04)

    private var leftMenuTitle: String { String(localized: "topBar.menu.left", bundle: .module, comment: "Left menu title (lists the left panel's mounted volumes)") }
    private var fileMenuTitle: String { String(localized: "topBar.menu.file", bundle: .module, comment: "File menu title") }
    private var commandMenuTitle: String { String(localized: "topBar.menu.command", bundle: .module, comment: "Command menu title") }
    private var optionsMenuTitle: String { String(localized: "topBar.menu.options", bundle: .module, comment: "Options menu title") }
    private var rightMenuTitle: String { String(localized: "topBar.menu.right", bundle: .module, comment: "Right menu title (lists the right panel's mounted volumes)") }
    private var rescanLabel: String { String(localized: "topBar.menu.rescan", bundle: .module, comment: "Rescan the current panel's volume list") }
    private var newFolderLabel: String { String(localized: "topBar.file.newFolder", bundle: .module, comment: "File menu: create a new folder (F7)") }
    private var copyLabel: String { String(localized: "topBar.file.copy", bundle: .module, comment: "File menu: copy selection (F5)") }
    private var moveLabel: String { String(localized: "topBar.file.move", bundle: .module, comment: "File menu: move selection (F6)") }
    private var deleteLabel: String { String(localized: "topBar.file.delete", bundle: .module, comment: "File menu: delete selection (F8)") }
    private var viewLabel: String { String(localized: "topBar.file.view", bundle: .module, comment: "File menu: open selection in the viewer (F3)") }
    private var editLabel: String { String(localized: "topBar.file.edit", bundle: .module, comment: "File menu: open selection in the editor (F4)") }
    private var quitLabel: String { String(localized: "topBar.file.quit", bundle: .module, comment: "File menu: quit the app") }
    private var refreshLabel: String { String(localized: "topBar.command.refresh", bundle: .module, comment: "Command menu: reload the active panel") }
    private var backLabel: String { String(localized: "topBar.command.back", bundle: .module, comment: "Command menu: navigate back") }
    private var forwardLabel: String { String(localized: "topBar.command.forward", bundle: .module, comment: "Command menu: navigate forward") }
    private var bookmarksLabel: String { String(localized: "topBar.command.bookmarks", bundle: .module, comment: "Command menu: open the Bookmarks popover") }
    private var userMenuLabel: String { String(localized: "topBar.command.userMenu", bundle: .module, comment: "Command menu: open the User Menu window") }
    private var showHiddenFilesLabel: String { String(localized: "topBar.options.showHiddenFiles", bundle: .module, comment: "Options menu: toggle hidden files in the active panel") }
    private var themeLabel: String { String(localized: "topBar.options.theme", bundle: .module, comment: "Options menu: Theme submenu title") }

    public var body: some View {
        HStack(spacing: 14) {
            Menu(leftMenuTitle) {
                ForEach(leftVolumes) { volume in
                    Button(volume.name) { onSelectLeftVolume(volume) }
                }
                if !leftVolumes.isEmpty { Divider() }
                Button(rescanLabel) { onRescanLeft() }
            }

            Menu(fileMenuTitle) {
                Button(newFolderLabel) { onFileAction(.mkdir) }
                Button(copyLabel) { onFileAction(.copy) }
                Button(moveLabel) { onFileAction(.move) }
                Button(deleteLabel) { onFileAction(.delete) }
                Divider()
                Button(viewLabel) { onFileAction(.view) }
                Button(editLabel) { onFileAction(.edit) }
                Divider()
                Button(quitLabel) { NSApp.terminate(nil) }
            }

            Menu(commandMenuTitle) {
                Button(refreshLabel) { onRefreshActive() }
                Divider()
                // No .keyboardShortcut here - Cmd+[/Cmd+] are already registered by the
                // native macOS menu bar's Go menu (AppCommands.swift); a second
                // registration for the same combo risks an ambiguous/duplicate firing.
                Button(backLabel) { onGoBackActive() }
                Button(forwardLabel) { onGoForwardActive() }
                Divider()
                Button(bookmarksLabel) { onOpenBookmarks() }
                Button(userMenuLabel) { onFileAction(.userMenu) }
            }

            Menu(optionsMenuTitle) {
                Button(showHiddenFilesLabel) { onToggleHiddenFiles() }
                Menu(themeLabel) {
                    ThemeMenu()
                }
            }

            Menu(rightMenuTitle) {
                ForEach(rightVolumes) { volume in
                    Button(volume.name) { onSelectRightVolume(volume) }
                }
                if !rightVolumes.isEmpty { Divider() }
                Button(rescanLabel) { onRescanRight() }
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

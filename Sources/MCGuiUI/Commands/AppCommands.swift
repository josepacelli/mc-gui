import SwiftUI
import AppKit
import MCGuiCore

/// Actions the File/View/Go/Window menu items route to (MB-02, MB-04, MB-05, MB-06).
/// Injected by the caller (`MCGuiApp`, Phase 11) - `MCGuiUI` has no dependency on
/// `MCGuiMacOS` or app-level window state, so this module can only declare "which menu
/// item calls which closure", not what the closure ultimately does (mirrors
/// `KeyboardShortcutActions`, T44). The Edit menu needs no closures here - Undo/Redo/Cut/
/// Copy/Paste/Select All route through the standard AppKit responder chain instead
/// (mirrors `EditorWindow.performEditAction`), since they act on whatever view currently
/// has focus rather than on app-level state.
public struct AppCommandActions {
    public var view: () -> Void
    public var edit: () -> Void
    public var copy: () -> Void
    public var move: () -> Void
    public var mkdir: () -> Void
    public var delete: () -> Void
    public var sortByName: () -> Void
    public var sortBySize: () -> Void
    public var sortByDate: () -> Void
    public var sortByType: () -> Void
    public var toggleHiddenFiles: () -> Void
    public var refresh: () -> Void
    public var navigateToParent: () -> Void
    public var goBack: () -> Void
    public var goForward: () -> Void
    public var goHome: () -> Void
    public var goComputer: () -> Void
    // VL-01: navigates the active panel to a mounted volume's root, selected from the
    // Go menu's dynamic volume list (see `AppCommands.volumes`).
    public var goToVolume: (VolumeInfo) -> Void
    public var showViewerWindow: () -> Void
    public var showEditorWindow: () -> Void
    // MB-01: opens the F1 Help window.
    public var showHelp: () -> Void

    public init(
        view: @escaping () -> Void = {},
        edit: @escaping () -> Void = {},
        copy: @escaping () -> Void = {},
        move: @escaping () -> Void = {},
        mkdir: @escaping () -> Void = {},
        delete: @escaping () -> Void = {},
        sortByName: @escaping () -> Void = {},
        sortBySize: @escaping () -> Void = {},
        sortByDate: @escaping () -> Void = {},
        sortByType: @escaping () -> Void = {},
        toggleHiddenFiles: @escaping () -> Void = {},
        refresh: @escaping () -> Void = {},
        navigateToParent: @escaping () -> Void = {},
        goBack: @escaping () -> Void = {},
        goForward: @escaping () -> Void = {},
        goHome: @escaping () -> Void = {},
        goComputer: @escaping () -> Void = {},
        goToVolume: @escaping (VolumeInfo) -> Void = { _ in },
        showViewerWindow: @escaping () -> Void = {},
        showEditorWindow: @escaping () -> Void = {},
        showHelp: @escaping () -> Void = {}
    ) {
        self.view = view
        self.edit = edit
        self.copy = copy
        self.move = move
        self.mkdir = mkdir
        self.delete = delete
        self.sortByName = sortByName
        self.sortBySize = sortBySize
        self.sortByDate = sortByDate
        self.sortByType = sortByType
        self.toggleHiddenFiles = toggleHiddenFiles
        self.refresh = refresh
        self.navigateToParent = navigateToParent
        self.goBack = goBack
        self.goForward = goForward
        self.goHome = goHome
        self.goComputer = goComputer
        self.goToVolume = goToVolume
        self.showViewerWindow = showViewerWindow
        self.showEditorWindow = showEditorWindow
        self.showHelp = showHelp
    }
}

/// SwiftUI `Commands` builder for the full native menu bar: File, Edit, View, Go, Window,
/// Help (MB-01..MB-07). The App menu itself needs no code here - AppKit supplies it
/// automatically for every app, with or without this `Commands` group installed.
///
/// Installed via `.commands { AppCommands(actions: ...) }` on the app's `Scene`
/// (`MCGuiApp`, Phase 11) alongside `.commandsRemoved()`, which strips SwiftUI's own
/// default File/Edit/View/Window/Help contributions first - without it, those defaults and
/// this type's identically-named menus would appear side by side as duplicates.
@MainActor
public struct AppCommands: Commands {
    private let actions: AppCommandActions
    // VL-01: the Go menu's dynamic volume list - a plain array (not itself observed
    // here), so the caller (`MCGuiApp`) must re-supply `AppCommands` when it changes for
    // the menu to reflect a mount/unmount.
    private let volumes: [VolumeInfo]

    // NSF3FunctionKey..NSF8FunctionKey mirror PanelView/ViewerWindow/EditorWindow/
    // KeyboardShortcuts' technique for binding physical F-keys via SwiftUI's `KeyEquivalent`.
    private static let f3Key = KeyEquivalent(Character(UnicodeScalar(NSF3FunctionKey)!))
    private static let f4Key = KeyEquivalent(Character(UnicodeScalar(NSF4FunctionKey)!))
    private static let f5Key = KeyEquivalent(Character(UnicodeScalar(NSF5FunctionKey)!))
    private static let f6Key = KeyEquivalent(Character(UnicodeScalar(NSF6FunctionKey)!))
    private static let f7Key = KeyEquivalent(Character(UnicodeScalar(NSF7FunctionKey)!))
    private static let f8Key = KeyEquivalent(Character(UnicodeScalar(NSF8FunctionKey)!))

    public init(actions: AppCommandActions, volumes: [VolumeInfo] = []) {
        self.actions = actions
        self.volumes = volumes
    }

    // MARK: - localized labels (I18N-01..04). Keyboard shortcuts (below) are never
    // translated, only these label strings.

    private var fileMenuTitle: String { String(localized: "appCommands.menu.file", bundle: .module, comment: "Native File menu title") }
    private var editMenuTitle: String { String(localized: "appCommands.menu.edit", bundle: .module, comment: "Native Edit menu title") }
    private var viewMenuTitle: String { String(localized: "appCommands.menu.view", bundle: .module, comment: "Native View menu title") }
    private var goMenuTitle: String { String(localized: "appCommands.menu.go", bundle: .module, comment: "Native Go menu title") }
    private var windowMenuTitle: String { String(localized: "appCommands.menu.window", bundle: .module, comment: "Native Window menu title") }
    private var helpMenuTitle: String { String(localized: "appCommands.menu.help", bundle: .module, comment: "Native Help menu title") }
    private var sortMenuTitle: String { String(localized: "appCommands.menu.sort", bundle: .module, comment: "View menu: Sort submenu title") }
    private var themeMenuTitle: String { String(localized: "appCommands.menu.theme", bundle: .module, comment: "View menu: Theme submenu title") }

    private var newFolderLabel: String { String(localized: "appCommands.file.newFolder", bundle: .module, comment: "File menu: create a new folder (F7)") }
    private var copyLabel: String { String(localized: "appCommands.file.copy", bundle: .module, comment: "File menu: copy selection (F5)") }
    private var moveLabel: String { String(localized: "appCommands.file.move", bundle: .module, comment: "File menu: move selection (F6)") }
    private var deleteLabel: String { String(localized: "appCommands.file.delete", bundle: .module, comment: "File menu: delete selection (F8)") }
    private var viewFileLabel: String { String(localized: "appCommands.file.view", bundle: .module, comment: "File menu: open selection in the viewer (F3)") }
    private var editFileLabel: String { String(localized: "appCommands.file.edit", bundle: .module, comment: "File menu: open selection in the editor (F4)") }
    private var quitLabel: String { String(localized: "appCommands.file.quit", bundle: .module, comment: "File menu: quit the app") }

    private var undoLabel: String { String(localized: "appCommands.edit.undo", bundle: .module, comment: "Edit menu: undo") }
    private var redoLabel: String { String(localized: "appCommands.edit.redo", bundle: .module, comment: "Edit menu: redo") }
    private var cutLabel: String { String(localized: "appCommands.edit.cut", bundle: .module, comment: "Edit menu: cut") }
    private var editCopyLabel: String { String(localized: "appCommands.edit.copy", bundle: .module, comment: "Edit menu: copy") }
    private var pasteLabel: String { String(localized: "appCommands.edit.paste", bundle: .module, comment: "Edit menu: paste") }
    private var selectAllLabel: String { String(localized: "appCommands.edit.selectAll", bundle: .module, comment: "Edit menu: select all") }

    private var sortByNameLabel: String { String(localized: "appCommands.view.sortByName", bundle: .module, comment: "View menu: sort the active panel by name") }
    private var sortBySizeLabel: String { String(localized: "appCommands.view.sortBySize", bundle: .module, comment: "View menu: sort the active panel by size") }
    private var sortByDateLabel: String { String(localized: "appCommands.view.sortByDate", bundle: .module, comment: "View menu: sort the active panel by date") }
    private var sortByTypeLabel: String { String(localized: "appCommands.view.sortByType", bundle: .module, comment: "View menu: sort the active panel by type") }
    private var showHiddenFilesLabel: String { String(localized: "appCommands.view.showHiddenFiles", bundle: .module, comment: "View menu: toggle hidden files") }
    private var refreshLabel: String { String(localized: "appCommands.view.refresh", bundle: .module, comment: "View menu: reload the active panel") }

    private var backLabel: String { String(localized: "appCommands.go.back", bundle: .module, comment: "Go menu: navigate back") }
    private var forwardLabel: String { String(localized: "appCommands.go.forward", bundle: .module, comment: "Go menu: navigate forward") }
    private var parentLabel: String { String(localized: "appCommands.go.parent", bundle: .module, comment: "Go menu: navigate to the parent directory") }
    private var homeLabel: String { String(localized: "appCommands.go.home", bundle: .module, comment: "Go menu: navigate to the home directory") }
    private var computerLabel: String { String(localized: "appCommands.go.computer", bundle: .module, comment: "Go menu: navigate to the computer/volumes root") }

    private var minimizeLabel: String { String(localized: "appCommands.window.minimize", bundle: .module, comment: "Window menu: minimize the key window") }
    private var zoomLabel: String { String(localized: "appCommands.window.zoom", bundle: .module, comment: "Window menu: zoom the key window") }
    private var viewerWindowLabel: String { String(localized: "appCommands.window.viewer", bundle: .module, comment: "Window menu: bring the viewer window to front") }
    private var editorWindowLabel: String { String(localized: "appCommands.window.editor", bundle: .module, comment: "Window menu: bring the editor window to front") }

    private var helpItemLabel: String { String(localized: "appCommands.help.item", bundle: .module, comment: "Help menu: opens the F1 Help window") }

    public var body: some Commands {
        // MB-02: File menu - New Folder (F7), Copy (F5), Move (F6), Delete (F8),
        // View (F3), Edit (F4), Quit (Cmd+Q).
        CommandMenu(fileMenuTitle) {
            Button(newFolderLabel) { actions.mkdir() }.keyboardShortcut(Self.f7Key, modifiers: [])
            Button(copyLabel) { actions.copy() }.keyboardShortcut(Self.f5Key, modifiers: [])
            Button(moveLabel) { actions.move() }.keyboardShortcut(Self.f6Key, modifiers: [])
            Button(deleteLabel) { actions.delete() }.keyboardShortcut(Self.f8Key, modifiers: [])
            Divider()
            Button(viewFileLabel) { actions.view() }.keyboardShortcut(Self.f3Key, modifiers: [])
            Button(editFileLabel) { actions.edit() }.keyboardShortcut(Self.f4Key, modifiers: [])
            Divider()
            Button(quitLabel) { NSApp.terminate(nil) }.keyboardShortcut("q", modifiers: .command)
        }

        // MB-03: Edit menu - Undo, Redo, Cut, Copy, Paste, Select All via the standard
        // AppKit responder chain.
        CommandMenu(editMenuTitle) {
            Button(undoLabel) { sendEditAction("undo:") }.keyboardShortcut("z", modifiers: .command)
            Button(redoLabel) { sendEditAction("redo:") }.keyboardShortcut("z", modifiers: [.command, .shift])
            Divider()
            Button(cutLabel) { sendEditAction("cut:") }.keyboardShortcut("x", modifiers: .command)
            Button(editCopyLabel) { sendEditAction("copy:") }.keyboardShortcut("c", modifiers: .command)
            Button(pasteLabel) { sendEditAction("paste:") }.keyboardShortcut("v", modifiers: .command)
            Divider()
            Button(selectAllLabel) { sendEditAction("selectAll:") }.keyboardShortcut("a", modifiers: .command)
        }

        // MB-04: View menu - Sort submenu, Show Hidden Files (Cmd+.), Refresh (Cmd+R),
        // Theme submenu.
        CommandMenu(viewMenuTitle) {
            Menu(sortMenuTitle) {
                Button(sortByNameLabel) { actions.sortByName() }.keyboardShortcut("1", modifiers: .command)
                Button(sortBySizeLabel) { actions.sortBySize() }.keyboardShortcut("2", modifiers: .command)
                Button(sortByDateLabel) { actions.sortByDate() }.keyboardShortcut("3", modifiers: .command)
                Button(sortByTypeLabel) { actions.sortByType() }.keyboardShortcut("4", modifiers: .command)
            }
            Button(showHiddenFilesLabel) { actions.toggleHiddenFiles() }.keyboardShortcut(".", modifiers: .command)
            Button(refreshLabel) { actions.refresh() }.keyboardShortcut("r", modifiers: .command)
            Divider()
            Menu(themeMenuTitle) {
                ThemeMenu()
            }
        }

        // MB-05: Go menu - Back (Cmd+[), Forward (Cmd+]), Parent (Cmd+Up), Home, Computer.
        CommandMenu(goMenuTitle) {
            Button(backLabel) { actions.goBack() }.keyboardShortcut("[", modifiers: .command)
            Button(forwardLabel) { actions.goForward() }.keyboardShortcut("]", modifiers: .command)
            Button(parentLabel) { actions.navigateToParent() }.keyboardShortcut(.upArrow, modifiers: .command)
            Divider()
            Button(homeLabel) { actions.goHome() }
            Button(computerLabel) { actions.goComputer() }
            if !volumes.isEmpty {
                Divider()
                ForEach(volumes) { volume in
                    Button(volume.name) { actions.goToVolume(volume) }
                }
            }
        }

        // MB-06: Window menu - Minimize (Cmd+M), Zoom, Viewer, Editor.
        CommandMenu(windowMenuTitle) {
            Button(minimizeLabel) { NSApp.keyWindow?.miniaturize(nil) }.keyboardShortcut("m", modifiers: .command)
            Button(zoomLabel) { NSApp.keyWindow?.zoom(nil) }
            Divider()
            Button(viewerWindowLabel) { actions.showViewerWindow() }
            Button(editorWindowLabel) { actions.showEditorWindow() }
        }

        // MB-01: Help menu - opens the F1 Help window. No .keyboardShortcut(.f1...) here:
        // PanelView already binds the physical F1 key directly (same caution as Cmd+[/]
        // above - a second registration risks an ambiguous/duplicate firing).
        CommandMenu(helpMenuTitle) {
            Button(helpItemLabel) { actions.showHelp() }
        }
    }

    /// Forwards a standard AppKit edit action to whichever view is currently first
    /// responder (MB-03), mirroring `EditorWindow.performEditAction`.
    private func sendEditAction(_ selectorName: String) {
        NSApp.sendAction(Selector(selectorName), to: nil, from: nil)
    }
}

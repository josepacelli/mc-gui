import SwiftUI
import AppKit

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
    public var showViewerWindow: () -> Void
    public var showEditorWindow: () -> Void

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
        showViewerWindow: @escaping () -> Void = {},
        showEditorWindow: @escaping () -> Void = {}
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
        self.showViewerWindow = showViewerWindow
        self.showEditorWindow = showEditorWindow
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
public struct AppCommands: Commands {
    private let actions: AppCommandActions

    // NSF3FunctionKey..NSF8FunctionKey mirror PanelView/ViewerWindow/EditorWindow/
    // KeyboardShortcuts' technique for binding physical F-keys via SwiftUI's `KeyEquivalent`.
    private static let f3Key = KeyEquivalent(Character(UnicodeScalar(NSF3FunctionKey)!))
    private static let f4Key = KeyEquivalent(Character(UnicodeScalar(NSF4FunctionKey)!))
    private static let f5Key = KeyEquivalent(Character(UnicodeScalar(NSF5FunctionKey)!))
    private static let f6Key = KeyEquivalent(Character(UnicodeScalar(NSF6FunctionKey)!))
    private static let f7Key = KeyEquivalent(Character(UnicodeScalar(NSF7FunctionKey)!))
    private static let f8Key = KeyEquivalent(Character(UnicodeScalar(NSF8FunctionKey)!))

    public init(actions: AppCommandActions) {
        self.actions = actions
    }

    public var body: some Commands {
        // MB-02: File menu - New Folder (F7), Copy (F5), Move (F6), Delete (F8),
        // View (F3), Edit (F4), Quit (Cmd+Q).
        CommandMenu("File") {
            Button("New Folder") { actions.mkdir() }.keyboardShortcut(Self.f7Key, modifiers: [])
            Button("Copy") { actions.copy() }.keyboardShortcut(Self.f5Key, modifiers: [])
            Button("Move") { actions.move() }.keyboardShortcut(Self.f6Key, modifiers: [])
            Button("Delete") { actions.delete() }.keyboardShortcut(Self.f8Key, modifiers: [])
            Divider()
            Button("View") { actions.view() }.keyboardShortcut(Self.f3Key, modifiers: [])
            Button("Edit") { actions.edit() }.keyboardShortcut(Self.f4Key, modifiers: [])
            Divider()
            Button("Quit") { NSApp.terminate(nil) }.keyboardShortcut("q", modifiers: .command)
        }

        // MB-03: Edit menu - Undo, Redo, Cut, Copy, Paste, Select All via the standard
        // AppKit responder chain.
        CommandMenu("Edit") {
            Button("Undo") { sendEditAction("undo:") }.keyboardShortcut("z", modifiers: .command)
            Button("Redo") { sendEditAction("redo:") }.keyboardShortcut("z", modifiers: [.command, .shift])
            Divider()
            Button("Cut") { sendEditAction("cut:") }.keyboardShortcut("x", modifiers: .command)
            Button("Copy") { sendEditAction("copy:") }.keyboardShortcut("c", modifiers: .command)
            Button("Paste") { sendEditAction("paste:") }.keyboardShortcut("v", modifiers: .command)
            Divider()
            Button("Select All") { sendEditAction("selectAll:") }.keyboardShortcut("a", modifiers: .command)
        }

        // MB-04: View menu - Sort submenu, Show Hidden Files (Cmd+.), Refresh (Cmd+R),
        // Theme submenu.
        CommandMenu("View") {
            Menu("Sort") {
                Button("Sort by Name") { actions.sortByName() }.keyboardShortcut("1", modifiers: .command)
                Button("Sort by Size") { actions.sortBySize() }.keyboardShortcut("2", modifiers: .command)
                Button("Sort by Date") { actions.sortByDate() }.keyboardShortcut("3", modifiers: .command)
                Button("Sort by Type") { actions.sortByType() }.keyboardShortcut("4", modifiers: .command)
            }
            Button("Show Hidden Files") { actions.toggleHiddenFiles() }.keyboardShortcut(".", modifiers: .command)
            Button("Refresh") { actions.refresh() }.keyboardShortcut("r", modifiers: .command)
            Divider()
            Menu("Theme") {
                ThemeMenu()
            }
        }

        // MB-05: Go menu - Back (Cmd+[), Forward (Cmd+]), Parent (Cmd+Up), Home, Computer.
        CommandMenu("Go") {
            Button("Back") { actions.goBack() }.keyboardShortcut("[", modifiers: .command)
            Button("Forward") { actions.goForward() }.keyboardShortcut("]", modifiers: .command)
            Button("Parent") { actions.navigateToParent() }.keyboardShortcut(.upArrow, modifiers: .command)
            Divider()
            Button("Home") { actions.goHome() }
            Button("Computer") { actions.goComputer() }
        }

        // MB-06: Window menu - Minimize (Cmd+M), Zoom, Viewer, Editor.
        CommandMenu("Window") {
            Button("Minimize") { NSApp.keyWindow?.miniaturize(nil) }.keyboardShortcut("m", modifiers: .command)
            Button("Zoom") { NSApp.keyWindow?.zoom(nil) }
            Divider()
            Button("Viewer") { actions.showViewerWindow() }
            Button("Editor") { actions.showEditorWindow() }
        }

        // MB-01: Help menu (presence only - spec.md defines no specific Help content).
        CommandMenu("Help") {
            Button("MCGui Help") {}
        }
    }

    /// Forwards a standard AppKit edit action to whichever view is currently first
    /// responder (MB-03), mirroring `EditorWindow.performEditAction`.
    private func sendEditAction(_ selectorName: String) {
        NSApp.sendAction(Selector(selectorName), to: nil, from: nil)
    }
}

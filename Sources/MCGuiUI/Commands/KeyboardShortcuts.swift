import SwiftUI
import AppKit

/// Actions the KN-07..KN-12 global shortcuts route to. Injected by the caller (`MCGuiApp`,
/// Phase 11) rather than referencing concrete windows/services directly - `MCGuiUI` has no
/// dependency on `MCGuiMacOS` or app-level window state, so this module can only declare
/// "which shortcut calls which closure", not what the closure ultimately does.
public struct KeyboardShortcutActions {
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
    public var navigateToParent: () -> Void
    public var goBack: () -> Void
    public var goForward: () -> Void
    public var enter: () -> Void
    public var escape: () -> Void

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
        navigateToParent: @escaping () -> Void = {},
        goBack: @escaping () -> Void = {},
        goForward: @escaping () -> Void = {},
        enter: @escaping () -> Void = {},
        escape: @escaping () -> Void = {}
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
        self.navigateToParent = navigateToParent
        self.goBack = goBack
        self.goForward = goForward
        self.enter = enter
        self.escape = escape
    }
}

/// SwiftUI `Commands` builder declaring every KN-07..KN-12 shortcut - F3-F8, Cmd+1/2/3/4,
/// Cmd+., Cmd+Up/[/], Enter, Escape - each routed to its `KeyboardShortcutActions` closure.
/// Installed into the app's `Scene` via `.commands { KeyboardShortcuts(actions: ...) }`
/// (`MCGuiApp`, Phase 11); this module only declares the shortcuts and their routing.
public struct KeyboardShortcuts: Commands {
    private let actions: KeyboardShortcutActions

    // NSF3FunctionKey..NSF8FunctionKey mirror PanelView/ViewerWindow/EditorWindow's
    // technique for binding physical F-keys via SwiftUI's `KeyEquivalent`.
    private static let f3Key = KeyEquivalent(Character(UnicodeScalar(NSF3FunctionKey)!))
    private static let f4Key = KeyEquivalent(Character(UnicodeScalar(NSF4FunctionKey)!))
    private static let f5Key = KeyEquivalent(Character(UnicodeScalar(NSF5FunctionKey)!))
    private static let f6Key = KeyEquivalent(Character(UnicodeScalar(NSF6FunctionKey)!))
    private static let f7Key = KeyEquivalent(Character(UnicodeScalar(NSF7FunctionKey)!))
    private static let f8Key = KeyEquivalent(Character(UnicodeScalar(NSF8FunctionKey)!))

    public init(actions: KeyboardShortcutActions) {
        self.actions = actions
    }

    public var body: some Commands {
        // KN-07: F3 (view), F4 (edit), F5 (copy), F6 (move), F7 (mkdir), F8 (delete).
        CommandMenu("File Actions") {
            Button("View") { actions.view() }.keyboardShortcut(Self.f3Key, modifiers: [])
            Button("Edit") { actions.edit() }.keyboardShortcut(Self.f4Key, modifiers: [])
            Button("Copy") { actions.copy() }.keyboardShortcut(Self.f5Key, modifiers: [])
            Button("Move") { actions.move() }.keyboardShortcut(Self.f6Key, modifiers: [])
            Button("New Folder") { actions.mkdir() }.keyboardShortcut(Self.f7Key, modifiers: [])
            Button("Delete") { actions.delete() }.keyboardShortcut(Self.f8Key, modifiers: [])
        }

        // KN-08: Cmd+1/2/3/4 sort by name/size/date/type. KN-09: Cmd+. toggle hidden files.
        CommandMenu("Sort") {
            Button("Sort by Name") { actions.sortByName() }.keyboardShortcut("1", modifiers: .command)
            Button("Sort by Size") { actions.sortBySize() }.keyboardShortcut("2", modifiers: .command)
            Button("Sort by Date") { actions.sortByDate() }.keyboardShortcut("3", modifiers: .command)
            Button("Sort by Type") { actions.sortByType() }.keyboardShortcut("4", modifiers: .command)
            Button("Toggle Hidden Files") { actions.toggleHiddenFiles() }.keyboardShortcut(".", modifiers: .command)
        }

        // KN-10: Cmd+Up (parent), Cmd+[ (back), Cmd+] (forward).
        CommandMenu("Navigate") {
            Button("Parent Directory") { actions.navigateToParent() }.keyboardShortcut(.upArrow, modifiers: .command)
            Button("Back") { actions.goBack() }.keyboardShortcut("[", modifiers: .command)
            Button("Forward") { actions.goForward() }.keyboardShortcut("]", modifiers: .command)
        }

        // KN-11: Enter (enter directory / open file). KN-12: Escape (close dialogs / clear selection).
        CommandMenu("Selection") {
            Button("Open") { actions.enter() }.keyboardShortcut(.return, modifiers: [])
            Button("Cancel") { actions.escape() }.keyboardShortcut(.escape, modifiers: [])
        }
    }
}

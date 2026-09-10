import Foundation

/// An action that can be triggered on a panel from outside `PanelView` itself. Both the
/// bottom `ButtonBar` and the in-window `TopBar`'s File menu (`classic-layout-parity`,
/// CL-05) need to invoke the same F3-F8 handling `PanelView` already runs for physical
/// key presses, but that handling lives behind `PanelView`'s private selection `@State`.
/// `MainWindow` forwards a value here through `PanelView`'s `pendingAction` binding for
/// whichever panel is currently active, mirroring how `onActivate`/`onViewFile` already
/// cross that same boundary in the other direction.
public enum PanelAction: Equatable, Sendable {
    case view
    case edit
    case copy
    case move
    case mkdir
    case delete
    // F2: opens the User Menu with this panel's current context (%f/%d/%D) - unlike the
    // others, it doesn't need a selection precondition or dialog of its own; PanelView
    // just computes the context and forwards it via `onUserMenu`.
    case userMenu
}

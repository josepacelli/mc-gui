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
}

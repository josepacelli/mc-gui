import Foundation
import Observation
import MCGuiCore

/// App-level state coordinating the two panels: holds a `PanelViewModel` per side and
/// tracks which panel is active, so views can highlight it (FS-01, FS-02).
@MainActor
@Observable
public final class MainWindowViewModel {
    public let leftPanel: PanelViewModel
    public let rightPanel: PanelViewModel
    public private(set) var activePanel: PanelSide

    public init(fileSystemService: FileSystemService, leftInitialPath: URL, rightInitialPath: URL) {
        self.leftPanel = PanelViewModel(fileSystemService: fileSystemService, initialPath: leftInitialPath)
        self.rightPanel = PanelViewModel(fileSystemService: fileSystemService, initialPath: rightInitialPath)
        self.activePanel = .left
    }

    /// The `PanelViewModel` for whichever side is currently active.
    public var activePanelViewModel: PanelViewModel {
        activePanel == .left ? leftPanel : rightPanel
    }

    /// Makes `side` the active panel (e.g. clicking into a panel, T22).
    public func activate(_ side: PanelSide) {
        activePanel = side
    }

    /// Toggles the active panel between left and right (e.g. Tab, wired in Phase 9).
    public func switchActivePanel() {
        activePanel = activePanel == .left ? .right : .left
    }
}

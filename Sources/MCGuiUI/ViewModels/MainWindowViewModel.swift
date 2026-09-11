import Foundation
import Observation
import MCGuiCore

@MainActor
@Observable
public final class MainWindowViewModel {
    public let leftPanel: PanelViewModel
    public let rightPanel: PanelViewModel
    public private(set) var activePanel: PanelSide

    public var leftPendingAction: PanelAction?
    public var rightPendingAction: PanelAction?

    public init(fileSystemService: FileSystemService, leftInitialPath: URL, rightInitialPath: URL) {
        self.leftPanel = PanelViewModel(fileSystemService: fileSystemService, initialPath: leftInitialPath)
        self.rightPanel = PanelViewModel(fileSystemService: fileSystemService, initialPath: rightInitialPath)
        self.activePanel = .left
    }

    public var activePanelViewModel: PanelViewModel {
        activePanel == .left ? leftPanel : rightPanel
    }

    public func activate(_ side: PanelSide) {
        activePanel = side
    }

    public func switchActivePanel() {
        activePanel = activePanel == .left ? .right : .left
    }

    public func triggerActivePanel(_ action: PanelAction) {
        switch activePanel {
        case .left: leftPendingAction = action
        case .right: rightPendingAction = action
        }
    }
}

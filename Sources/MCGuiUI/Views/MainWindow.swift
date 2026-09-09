import SwiftUI
import MCGuiCore

/// The root window: two `PanelView`s side by side in an `HSplitView`, coordinated by a
/// `MainWindowViewModel`.
public struct MainWindow: View {
    public let viewModel: MainWindowViewModel

    public init(viewModel: MainWindowViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        HSplitView {
            PanelView(
                viewModel: viewModel.leftPanel,
                isActive: viewModel.activePanel == .left,
                onActivate: { viewModel.activate(.left) }
            )
            PanelView(
                viewModel: viewModel.rightPanel,
                isActive: viewModel.activePanel == .right,
                onActivate: { viewModel.activate(.right) }
            )
        }
    }
}

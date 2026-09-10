import SwiftUI
import MCGuiCore

/// The root window: two `PanelView`s side by side in an `HSplitView`, coordinated by a
/// `MainWindowViewModel`.
public struct MainWindow: View {
    public let viewModel: MainWindowViewModel

    // TH-05: reading the same `@AppStorage` key `ThemeMenu` (T47) writes to means this
    // view re-renders immediately whenever the user picks a different theme option, with
    // no direct reference between the two views needed.
    @AppStorage(ThemePreference.storageKey) private var themePreference: ThemePreference = .system

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
        .preferredColorScheme(themePreference.colorScheme)
    }
}

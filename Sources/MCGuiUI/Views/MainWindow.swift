import SwiftUI
import MCGuiCore

/// The root window: two `PanelView`s side by side in an `HSplitView`, coordinated by a
/// `MainWindowViewModel`.
public struct MainWindow: View {
    public let viewModel: MainWindowViewModel
    // WindowManager gap closure (T50): forwarded from PanelView's own onViewFile/
    // onEditFile, tagged with which side (left/right) triggered it - `WindowManager.
    // showViewer(for:panel:)` needs the panel side to read that panel's file list for
    // Tab/Shift+Tab navigation (FV-05).
    public var onViewFile: (FileEntry, PanelSide) -> Void
    public var onEditFile: (FileEntry, PanelSide) -> Void

    // TH-05: reading the same `@AppStorage` key `ThemeMenu` (T47) writes to means this
    // view re-renders immediately whenever the user picks a different theme option, with
    // no direct reference between the two views needed.
    @AppStorage(ThemePreference.storageKey) private var themePreference: ThemePreference = .system

    public init(
        viewModel: MainWindowViewModel,
        onViewFile: @escaping (FileEntry, PanelSide) -> Void = { _, _ in },
        onEditFile: @escaping (FileEntry, PanelSide) -> Void = { _, _ in }
    ) {
        self.viewModel = viewModel
        self.onViewFile = onViewFile
        self.onEditFile = onEditFile
    }

    public var body: some View {
        HSplitView {
            PanelView(
                viewModel: viewModel.leftPanel,
                isActive: viewModel.activePanel == .left,
                onActivate: { viewModel.activate(.left) },
                onViewFile: { entry in onViewFile(entry, .left) },
                onEditFile: { entry in onEditFile(entry, .left) }
            )
            PanelView(
                viewModel: viewModel.rightPanel,
                isActive: viewModel.activePanel == .right,
                onActivate: { viewModel.activate(.right) },
                onViewFile: { entry in onViewFile(entry, .right) },
                onEditFile: { entry in onEditFile(entry, .right) }
            )
        }
        .preferredColorScheme(themePreference.colorScheme)
    }
}

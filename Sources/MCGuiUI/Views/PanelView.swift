import SwiftUI
import MCGuiCore

/// A single file panel: renders `PanelViewModel.entries`, shows loading/error overlays,
/// and tracks focus so the active panel can be visually distinguished.
///
/// This is a focus-state skeleton only - full keyboard navigation (arrows, Tab, Space,
/// Insert, F-keys) is wired in Phase 9 (`PanelCommands`/`KeyboardShortcuts`). The
/// context menu below is a stub; its actions are wired in Phase 6 (file operations).
public struct PanelView: View {
    public let viewModel: PanelViewModel
    public let isActive: Bool
    public var onActivate: () -> Void

    @FocusState private var isFocused: Bool

    public init(viewModel: PanelViewModel, isActive: Bool, onActivate: @escaping () -> Void = {}) {
        self.viewModel = viewModel
        self.isActive = isActive
        self.onActivate = onActivate
    }

    public var body: some View {
        ZStack {
            List(viewModel.entries) { entry in
                FileRow(entry: entry)
                    .contextMenu {
                        Text(entry.name)
                    }
            }
            .focusable()
            .focused($isFocused)
            .onChange(of: isFocused) { _, focused in
                if focused { onActivate() }
            }
            .onTapGesture { onActivate() }

            if viewModel.isLoading {
                LoadingOverlay()
            }

            if let errorMessage = viewModel.errorMessage {
                ErrorAlert(message: errorMessage)
            }
        }
        .border(isActive ? Color.accentColor : Color.clear, width: 2)
        .task {
            await viewModel.load()
        }
    }
}

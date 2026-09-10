import SwiftUI
import AppKit
import MCGuiCore

/// The file viewer window: mode tabs (Text/Image/Hex), a search bar, a status bar, and
/// the FV-05/FV-06 key bindings (Tab/Shift+Tab next/previous file, Cmd+F focus search).
///
/// Self-contained: loads `initialURL` on appear via the injected `ViewerViewModel`, whose
/// `mode` already reflects the loaded content's kind (FV-01..FV-04) - opening this view
/// with the right file already displays it in the correct mode, with no extra wiring here.
///
// SPEC_DEVIATION (T38): spec.md's AC1 defines F3 only as the shortcut that *opens* the
// viewer from a panel selection - it says nothing about what F3 does once the viewer is
// already open, and neither does design.md. Bound here to `onClose()` (F3 toggles closed
// the window it opened), the only self-consistent behavior available within this view
// alone. Wiring the actual "press F3 on a panel selection to construct and present this
// window" (and supplying the panel's file list to the underlying `ViewerServiceImpl` via
// its concrete-type-only `setFileList(_:)` - `ViewerViewModel` only holds the
// `ViewerService` protocol, and MCGuiUI cannot depend on MCGuiMacOS to reach the concrete
// type) is out of scope for this task, which only builds the window itself.
public struct ViewerWindow: View {
    public let viewModel: ViewerViewModel
    public let initialURL: URL
    public var onClose: () -> Void

    @FocusState private var searchFieldFocused: Bool
    // FV-03: image zoom/pan state.
    @State private var imageScale: CGFloat = 1
    @State private var imageOffset: CGSize = .zero
    @State private var lastImageOffset: CGSize = .zero

    // NSF3FunctionKey mirrors PanelView's F5-F8 technique for binding physical F-keys.
    private static let f3Key = KeyEquivalent(Character(UnicodeScalar(NSF3FunctionKey)!))

    public init(viewModel: ViewerViewModel, initialURL: URL, onClose: @escaping () -> Void = {}) {
        self.viewModel = viewModel
        self.initialURL = initialURL
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            searchBar
            Divider()
            contentArea
            Divider()
            statusBar
        }
        .focusable()
        .onKeyPress(keys: [.tab, Self.f3Key]) { press in
            handleKeyPress(press)
            return .handled
        }
        .task { await viewModel.load(initialURL) }
    }

    // MARK: - toolbar: mode tabs (FV-01)

    private var toolbar: some View {
        HStack {
            Picker("Mode", selection: modeBinding) {
                Text("Text").tag(ViewerMode.text)
                Text("Image").tag(ViewerMode.image)
                Text("Hex").tag(ViewerMode.hex)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 240)

            Spacer()

            Button {
                searchFieldFocused = true
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .keyboardShortcut("f", modifiers: .command)
            .help("Find (⌘F)")
        }
        .padding(8)
    }

    private var modeBinding: Binding<ViewerMode> {
        Binding(get: { viewModel.mode }, set: { viewModel.setMode($0) })
    }

    // MARK: - search bar (FV-06)

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search", text: searchQueryBinding)
                .focused($searchFieldFocused)
            if !viewModel.searchMatches.isEmpty {
                Text("\(viewModel.searchMatches.count) matches")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private var searchQueryBinding: Binding<String> {
        Binding(get: { viewModel.searchQuery }, set: { viewModel.searchQuery = $0 })
    }

    // MARK: - content area (FV-02, FV-03, FV-04)

    @ViewBuilder
    private var contentArea: some View {
        if let errorMessage = viewModel.errorMessage {
            ErrorAlert(message: errorMessage)
        } else if viewModel.isLoading {
            LoadingOverlay()
        } else {
            switch viewModel.mode {
            case .text:
                textContent
            case .image:
                imageContent
            case .hex:
                HexView(data: viewModel.rawData ?? Data())
            }
        }
    }

    // SPEC_DEVIATION (Fix 5, validation.md): FV-02 asks for syntax highlighting *and*
    // line numbers. Line numbers are implemented below (a `LazyVStack` gutter, lazy so
    // FV-07's 100MB-file requirement still holds - only visible rows are built). Full
    // tokenized syntax highlighting is not: mirrors `EditorWindow`'s ED-02 precedent
    // (monospaced text without per-token coloring, design.md's own documented risk
    // fallback) - this file previously claimed "Verified" for FV-02 without either half
    // implemented, which validation.md flagged as an over-claim; spec.md now matches
    // `EditorWindow`'s honest `Implementing` status for the same category of gap.
    private var textContent: some View {
        ScrollView([.vertical, .horizontal]) {
            if case .text(let text) = viewModel.content {
                let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1)")
                                .frame(minWidth: 40, alignment: .trailing)
                                .foregroundStyle(.secondary)
                            Text(String(line))
                        }
                        .font(.system(.body, design: .monospaced))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }
        }
    }

    // FV-03: pinch/scroll to zoom, drag to pan, double-click to reset - `@State` lives on
    // `ViewerWindow` itself since it resets naturally when a new file loads a fresh view.
    private var imageContent: some View {
        ScrollView([.horizontal, .vertical]) {
            if case .image(let data) = viewModel.content, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(imageScale)
                    .offset(imageOffset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { imageScale = max(0.1, $0) }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                imageOffset = CGSize(
                                    width: lastImageOffset.width + value.translation.width,
                                    height: lastImageOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in lastImageOffset = imageOffset }
                    )
                    .onTapGesture(count: 2) {
                        imageScale = 1
                        imageOffset = .zero
                        lastImageOffset = .zero
                    }
            }
        }
    }

    // MARK: - status bar

    private var statusBar: some View {
        HStack {
            Text(initialURL.lastPathComponent)
            Spacer()
            Text(viewModel.mode.rawValue.capitalized)
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .padding(8)
    }

    // MARK: - key handling: Tab/Shift+Tab (FV-05), F3 (close)

    private func handleKeyPress(_ press: KeyPress) {
        switch press.key.character {
        case KeyEquivalent.tab.character:
            if press.modifiers.contains(.shift) {
                Task { await viewModel.previous() }
            } else {
                Task { await viewModel.next() }
            }
        case Self.f3Key.character:
            onClose()
        default:
            break
        }
    }
}

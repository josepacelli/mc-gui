import SwiftUI
import AppKit
import MCGuiCore

@MainActor
public struct ViewerWindow: View {
    public let viewModel: ViewerViewModel
    public let initialURL: URL
    public var onClose: () -> Void

    @FocusState private var searchFieldFocused: Bool
    @State private var imageScale: CGFloat = 1
    @State private var imageOffset: CGSize = .zero
    @State private var lastImageOffset: CGSize = .zero

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


    private static func modeLabel(_ mode: ViewerMode) -> String {
        switch mode {
        case .text: return String(localized: "viewer.mode.text", bundle: .module, comment: "Text viewer mode")
        case .image: return String(localized: "viewer.mode.image", bundle: .module, comment: "Image viewer mode")
        case .hex: return String(localized: "viewer.mode.hex", bundle: .module, comment: "Hex viewer mode")
        }
    }


    private var toolbar: some View {
        HStack {
            Picker(String(localized: "viewer.picker.mode", bundle: .module, comment: "Mode picker's accessibility/VoiceOver label"), selection: modeBinding) {
                Text(Self.modeLabel(.text)).tag(ViewerMode.text)
                Text(Self.modeLabel(.image)).tag(ViewerMode.image)
                Text(Self.modeLabel(.hex)).tag(ViewerMode.hex)
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
            .help(String(localized: "viewer.button.find.help", bundle: .module, comment: "Find button tooltip (⌘F unchanged)"))
        }
        .padding(8)
    }

    private var modeBinding: Binding<ViewerMode> {
        Binding(get: { viewModel.mode }, set: { viewModel.setMode($0) })
    }


    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(String(localized: "viewer.field.search", bundle: .module, comment: "Search text field placeholder"), text: searchQueryBinding)
                .focused($searchFieldFocused)
            if !viewModel.searchMatches.isEmpty {
                Text(
                    String(
                        format: NSLocalizedString(
                            "viewer.search.matchCount",
                            bundle: .module,
                            comment: "Number of search matches found. %1$d is the match count."
                        ),
                        viewModel.searchMatches.count
                    )
                )
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
                            Text(SyntaxHighlighter.highlight(line))
                        }
                        .font(.system(.body, design: .monospaced))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }
        }
    }

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


    private var statusBar: some View {
        HStack {
            Text(initialURL.lastPathComponent)
            Spacer()
            Text(Self.modeLabel(viewModel.mode))
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .padding(8)
    }


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

import SwiftUI
import AppKit
import MCGuiCore

@MainActor
public struct EditorWindow: View {
    public let viewModel: EditorWindowViewModel
    public var onClosed: () -> Void

    @State private var showFindBar = false
    @State private var showReplaceField = false
    @State private var findQuery = ""
    @State private var replaceQuery = ""
    @State private var lastMatchLocation = 0
    @State private var saveChangesViewModel: SaveChangesDialogViewModel?
    @FocusState private var findFieldFocused: Bool

    private static let f4Key = KeyEquivalent(Character(UnicodeScalar(NSF4FunctionKey)!))

    public init(viewModel: EditorWindowViewModel, onClosed: @escaping () -> Void = {}) {
        self.viewModel = viewModel
        self.onClosed = onClosed
    }

    private var contentBinding: Binding<String> {
        Binding(get: { viewModel.content }, set: { viewModel.content = $0 })
    }

    public var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if showFindBar {
                findReplaceBar
                Divider()
            }
            EditorTextView(text: contentBinding)
            Divider()
            statusBar
        }
        .focusable()
        .onKeyPress(keys: [Self.f4Key]) { _ in
            attemptClose()
            return .handled
        }
        .sheet(isPresented: saveChangesPresented) {
            if let saveChangesViewModel {
                SaveChangesDialog(viewModel: saveChangesViewModel)
            }
        }
    }


    private var toolbar: some View {
        HStack {
            Button { performEditAction("cut:") } label: { Image(systemName: "scissors") }
                .help(String(localized: "editor.button.cut.help", bundle: .module, comment: "Cut button tooltip"))
            Button { performEditAction("copy:") } label: { Image(systemName: "doc.on.doc") }
                .help(String(localized: "editor.button.copy.help", bundle: .module, comment: "Copy button tooltip"))
            Button { performEditAction("paste:") } label: { Image(systemName: "clipboard") }
                .help(String(localized: "editor.button.paste.help", bundle: .module, comment: "Paste button tooltip"))

            Divider()

            Button { performEditAction("undo:") } label: { Image(systemName: "arrow.uturn.backward") }
                .help(String(localized: "editor.button.undo.help", bundle: .module, comment: "Undo button tooltip"))
            Button { performEditAction("redo:") } label: { Image(systemName: "arrow.uturn.forward") }
                .help(String(localized: "editor.button.redo.help", bundle: .module, comment: "Redo button tooltip"))
            Button { performEditAction("selectAll:") } label: { Image(systemName: "selection.pin.in.out") }
                .help(String(localized: "editor.button.selectAll.help", bundle: .module, comment: "Select All button tooltip (⌘A unchanged)"))
                .keyboardShortcut("a", modifiers: .command)

            Spacer()

            Button {
                Task { await viewModel.save() }
            } label: {
                Image(systemName: "square.and.arrow.down")
            }
            .keyboardShortcut("s", modifiers: .command)
            .help(String(localized: "editor.button.save.help", bundle: .module, comment: "Save button tooltip (⌘S unchanged)"))

            Button {
                openFindBar(replaceMode: false)
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .keyboardShortcut("f", modifiers: .command)
            .help(String(localized: "editor.button.find.help", bundle: .module, comment: "Find button tooltip (⌘F unchanged)"))

            Button {
                openFindBar(replaceMode: true)
            } label: {
                Image(systemName: "arrow.left.arrow.right")
            }
            .keyboardShortcut("f", modifiers: [.command, .option])
            .help(String(localized: "editor.button.findReplace.help", bundle: .module, comment: "Find & Replace button tooltip (⌥⌘F unchanged)"))
        }
        .padding(8)
    }

    private func performEditAction(_ selectorName: String) {
        NSApp.sendAction(Selector(selectorName), to: nil, from: nil)
    }


    private var findReplaceBar: some View {
        HStack {
            TextField(String(localized: "editor.field.find", bundle: .module, comment: "Find text field placeholder"), text: $findQuery)
                .focused($findFieldFocused)
            Button(String(localized: "editor.button.findNext", bundle: .module, comment: "Find the next match")) { findNext() }
                .disabled(findQuery.isEmpty)

            if showReplaceField {
                TextField(String(localized: "editor.field.replace", bundle: .module, comment: "Replace text field placeholder"), text: $replaceQuery)
                Button(String(localized: "editor.button.replaceAll", bundle: .module, comment: "Replace every match")) { replaceAll() }
                    .disabled(findQuery.isEmpty)
            }

            Spacer()
            Button(String(localized: "editor.button.done", bundle: .module, comment: "Close the find/replace bar")) { showFindBar = false }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private func openFindBar(replaceMode: Bool) {
        showFindBar = true
        showReplaceField = replaceMode
        findFieldFocused = true
    }

    private func findNext() {
        guard let match = Self.nextMatch(in: viewModel.content, query: findQuery, after: lastMatchLocation) else { return }
        lastMatchLocation = match.location + match.length
    }

    private func replaceAll() {
        let result = Self.replaceAll(in: viewModel.content, query: findQuery, replacement: replaceQuery)
        viewModel.content = result.text
        lastMatchLocation = 0
    }


    private var statusBar: some View {
        HStack {
            Text(
                viewModel.fileURL.lastPathComponent
                    + (viewModel.isDirty ? String(localized: "editor.status.editedSuffix", bundle: .module, comment: "Appended to the file name in the status bar when there are unsaved changes") : "")
            )
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
            Spacer()
        }
        .font(.caption)
        .padding(8)
    }


    private func attemptClose() {
        if viewModel.attemptClose() {
            onClosed()
            return
        }
        saveChangesViewModel = SaveChangesDialogViewModel(fileName: viewModel.fileURL.lastPathComponent) { result in
            Task { await handleSaveChangesResult(result) }
        }
    }

    private func handleSaveChangesResult(_ result: SaveChangesResult) async {
        switch result {
        case .save:
            await viewModel.saveAndClose()
            if viewModel.isClosed { onClosed() }
        case .discard:
            viewModel.discardAndClose()
            onClosed()
        case .cancel:
            break
        }
        saveChangesViewModel = nil
    }

    private var saveChangesPresented: Binding<Bool> {
        Binding(get: { saveChangesViewModel != nil }, set: { if !$0 { saveChangesViewModel = nil } })
    }


    nonisolated static func nextMatch(in text: String, query: String, after location: Int) -> SearchMatch? {
        let matches = findMatches(in: text, query: query)
        guard !matches.isEmpty else { return nil }
        return matches.first(where: { $0.location >= location }) ?? matches.first
    }

    nonisolated static func replaceAll(in text: String, query: String, replacement: String) -> (text: String, count: Int) {
        let matches = findMatches(in: text, query: query)
        guard !matches.isEmpty else { return (text, 0) }

        let haystack = text as NSString
        var result = ""
        var cursor = 0
        for match in matches {
            result += haystack.substring(with: NSRange(location: cursor, length: match.location - cursor))
            result += replacement
            cursor = match.location + match.length
        }
        result += haystack.substring(from: cursor)
        return (result, matches.count)
    }

    private nonisolated static func findMatches(in text: String, query: String) -> [SearchMatch] {
        guard !query.isEmpty else { return [] }

        let haystack = text as NSString
        var matches: [SearchMatch] = []
        var searchRange = NSRange(location: 0, length: haystack.length)

        while searchRange.length > 0 {
            let found = haystack.range(of: query, options: .caseInsensitive, range: searchRange)
            guard found.location != NSNotFound else { break }
            matches.append(SearchMatch(location: found.location, length: found.length))
            let nextLocation = found.location + found.length
            searchRange = NSRange(location: nextLocation, length: haystack.length - nextLocation)
        }

        return matches
    }
}

private struct EditorTextView: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isRichText = false
        textView.isEditable = true
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.string = text
        textView.delegate = context.coordinator
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView, textView.string != text else { return }
        textView.string = text
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        let text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
        }
    }
}

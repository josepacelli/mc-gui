import SwiftUI
import AppKit
import MCGuiCore

/// The text editor window: a toolbar (cut/copy/paste/undo/redo/select-all, save,
/// find/replace), an `NSTextView` wrapper, a find/replace bar, a status bar, and the
/// ED-01/ED-09/ED-10 key bindings (F4, Cmd+S, Cmd+F, Cmd+Option+F).
///
// SPEC_DEVIATION (T43): design.md's Assumptions table names "TextKit 2" for syntax
// highlighting but also flags it in Risks & Concerns as a risk with an explicit fallback
// ("fallback to basic coloring if needed"). `EditorTextView` below uses that documented
// fallback - a monospaced `NSTextView` (TextKit 2 is NSTextView's default backing store on
// macOS 14+) without per-token syntax coloring. Full tokenized highlighting is out of this
// task's budget; this satisfies ED-02 to the degree design.md itself anticipated as
// acceptable.
//
// SPEC_DEVIATION (T43): mirrors T38's `ViewerWindow` precedent - spec.md's ED-01 defines
// F4 only as the shortcut that *opens* the editor from a panel selection; neither spec.md
// nor design.md says what F4 does once the editor is already open. Bound here to an
// attempt-to-close (same self-consistent choice `ViewerWindow` made for F3). Constructing
// and presenting this window when F4 is pressed on a panel selection is cross-target
// wiring that belongs to a future task (MCGuiApp, Phase 11) - out of scope here.
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

    // NSF4FunctionKey mirrors PanelView's F5-F8 / ViewerWindow's F3 technique for binding
    // physical F-keys.
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

    // MARK: - toolbar (ED-09: cut/copy/paste/undo/redo/select-all; ED-04: save; ED-10: find/replace)

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

    /// Forwards a standard AppKit edit action (cut/copy/paste/undo/redo/selectAll) to
    /// whichever view is currently first responder - the `NSTextView` inside
    /// `EditorTextView` while the editor has focus (ED-09).
    private func performEditAction(_ selectorName: String) {
        NSApp.sendAction(Selector(selectorName), to: nil, from: nil)
    }

    // MARK: - find/replace bar (ED-10)

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

    // MARK: - status bar

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

    // MARK: - close flow (ED-05..ED-08)

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

    // MARK: - Pure helpers (unit-tested; the body above is thin declarative glue)

    /// Finds the next case-insensitive occurrence of `query` in `text` at or after
    /// `location`, wrapping to the first occurrence when none remain after that point.
    /// `nil` when `query` is empty or not present anywhere in `text`.
    nonisolated static func nextMatch(in text: String, query: String, after location: Int) -> SearchMatch? {
        let matches = findMatches(in: text, query: query)
        guard !matches.isEmpty else { return nil }
        return matches.first(where: { $0.location >= location }) ?? matches.first
    }

    /// Replaces every case-insensitive occurrence of `query` with `replacement` in `text`.
    /// Returns the new text and the number of replacements made (0 for an empty query or
    /// no matches).
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

    /// All case-insensitive, non-overlapping occurrences of `query` in `text`, in order.
    /// Mirrors `ViewerServiceImpl.search`'s scanning loop.
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

/// `NSViewRepresentable` wrapper bridging a plain `NSTextView` (in an `NSScrollView`) to
/// SwiftUI, with `allowsUndo` enabled so the toolbar's Undo/Redo buttons (ED-09) work via
/// the standard AppKit responder chain.
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

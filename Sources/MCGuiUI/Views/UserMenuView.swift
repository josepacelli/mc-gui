import SwiftUI

public struct UserMenuContext: Equatable {
    public var currentFile: URL?
    public var currentDir: URL
    public var otherDir: URL

    public init(currentFile: URL?, currentDir: URL, otherDir: URL) {
        self.currentFile = currentFile
        self.currentDir = currentDir
        self.otherDir = otherDir
    }
}

public struct UserMenuEntry: Identifiable, Hashable {
    public let id: UUID
    public let label: String
    public let command: String

    public init(id: UUID = UUID(), label: String, command: String) {
        self.id = id
        self.label = label
        self.command = command
    }
}

public struct UserMenuRunResult: Equatable {
    public var output: String
    public var exitCode: Int32

    public init(output: String, exitCode: Int32) {
        self.output = output
        self.exitCode = exitCode
    }
}

public struct UserMenuActions {
    public var list: () async throws -> [UserMenuEntry]
    public var add: (UserMenuEntry) async throws -> Void
    public var remove: (UUID) async throws -> Void
    public var run: (UserMenuEntry, UserMenuContext) async -> UserMenuRunResult

    public init(
        list: @escaping () async throws -> [UserMenuEntry] = { [] },
        add: @escaping (UserMenuEntry) async throws -> Void = { _ in },
        remove: @escaping (UUID) async throws -> Void = { _ in },
        run: @escaping (UserMenuEntry, UserMenuContext) async -> UserMenuRunResult = { _, _ in
            UserMenuRunResult(output: "", exitCode: 0)
        }
    ) {
        self.list = list
        self.add = add
        self.remove = remove
        self.run = run
    }
}

@MainActor
@Observable
public final class UserMenuViewModel {
    private let actions: UserMenuActions
    public private(set) var items: [UserMenuEntry] = []
    public private(set) var errorMessage: String?
    public private(set) var lastResult: UserMenuRunResult?
    public private(set) var isRunning = false

    public init(actions: UserMenuActions) {
        self.actions = actions
    }

    public func refresh() async {
        do {
            items = try await actions.list()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func addItem(label: String, command: String) async {
        guard !label.isEmpty, !command.isEmpty else { return }
        do {
            try await actions.add(UserMenuEntry(label: label, command: command))
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func remove(id: UUID) async {
        do {
            try await actions.remove(id)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func run(_ item: UserMenuEntry, context: UserMenuContext) async {
        isRunning = true
        lastResult = nil
        lastResult = await actions.run(item, context)
        isRunning = false
    }
}

@MainActor
public struct UserMenuView: View {
    public let viewModel: UserMenuViewModel
    public var context: UserMenuContext

    @State private var newLabel = ""
    @State private var newCommand = ""
    @State private var showingAddForm = false

    public init(viewModel: UserMenuViewModel, context: UserMenuContext) {
        self.viewModel = viewModel
        self.context = context
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(String(localized: "userMenu.header.title", bundle: .module, comment: "User Menu window title"))
                    .font(.headline)
                Spacer()
                Button {
                    showingAddForm.toggle()
                } label: {
                    Image(systemName: "plus")
                }
                .help(String(localized: "userMenu.button.addCommand.help", bundle: .module, comment: "Add-command button tooltip"))
            }
            .padding(8)

            if showingAddForm {
                addForm
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 8)
            }

            List(viewModel.items) { item in
                itemRow(item)
            }

            resultArea
        }
        .task { await viewModel.refresh() }
    }

    private var addForm: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField(String(localized: "userMenu.field.label", bundle: .module, comment: "New item's label text field"), text: $newLabel)
            TextField(
                String(localized: "userMenu.field.commandPlaceholder", bundle: .module, comment: "New item's shell command text field. %f/%d/%D are UserMenuRunner's own literal expansion tokens (current file/dir/other dir), not Swift format specifiers - never substituted, keep them unchanged."),
                text: $newCommand
            )
            HStack {
                Spacer()
                Button(String(localized: "userMenu.button.cancel", bundle: .module, comment: "Cancel adding a new item")) { cancelAddForm() }
                Button(String(localized: "userMenu.button.add", bundle: .module, comment: "Confirm adding the new item")) {
                    Task {
                        await viewModel.addItem(label: newLabel, command: newCommand)
                        cancelAddForm()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newLabel.isEmpty || newCommand.isEmpty)
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }

    private func cancelAddForm() {
        newLabel = ""
        newCommand = ""
        showingAddForm = false
    }

    private func itemRow(_ item: UserMenuEntry) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(item.label)
                Text(item.command)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button(String(localized: "userMenu.button.run", bundle: .module, comment: "Run this item's command")) {
                Task { await viewModel.run(item, context: context) }
            }
            Button {
                Task { await viewModel.remove(id: item.id) }
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.plain)
            .help(String(localized: "userMenu.button.remove.help", bundle: .module, comment: "Remove-item button tooltip"))
        }
    }

    @ViewBuilder
    private var resultArea: some View {
        if viewModel.isRunning {
            ProgressView()
                .padding(8)
        } else if let result = viewModel.lastResult {
            Divider()
            ScrollView {
                Text(result.output.isEmpty ? String(localized: "userMenu.result.noOutput", bundle: .module, comment: "Shown when the last run produced no output") : result.output)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(result.exitCode == 0 ? Color.primary : Color.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(maxHeight: 150)
            Text(
                String(
                    format: NSLocalizedString(
                        "userMenu.result.exitCode",
                        bundle: .module,
                        comment: "Exit code of the last run command. %1$d is the exit code."
                    ),
                    result.exitCode
                )
            )
            .font(.caption2)
            .foregroundStyle(result.exitCode == 0 ? Color.secondary : Color.red)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
    }
}

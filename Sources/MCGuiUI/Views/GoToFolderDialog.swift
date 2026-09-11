import SwiftUI
import MCGuiCore

@MainActor
public struct GoToFolderDialog: View {
    @Bindable public var viewModel: GoToFolderDialogViewModel
    public var onCancel: () -> Void

    public init(viewModel: GoToFolderDialogViewModel, onCancel: @escaping () -> Void = {}) {
        self.viewModel = viewModel
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "goToFolder.title", bundle: .module, comment: "Go to Folder dialog title"))
                .font(.headline)

            TextField(
                String(localized: "goToFolder.field.path", bundle: .module, comment: "Go to Folder dialog: path text field label"),
                text: $viewModel.path
            )
            .textFieldStyle(.roundedBorder)
            .onSubmit { Task { await viewModel.confirm() } }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            ScrollViewReader { proxy in
                List {
                    DirectoryTreeRow(node: viewModel.root, selectedPath: viewModel.selectedURL, onSelect: viewModel.selectNode)
                }
                .listStyle(.inset)
                .frame(minHeight: 260)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.3)))
                .task {
                    if let revealed = await viewModel.expandToCurrentPath() {
                        proxy.scrollTo(revealed, anchor: .center)
                    }
                }
            }

            HStack {
                Spacer()
                Button(String(localized: "goToFolder.button.cancel", bundle: .module, comment: "Cancel button"), role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(String(localized: "goToFolder.button.go", bundle: .module, comment: "Go to folder button")) {
                    Task { await viewModel.confirm() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(minWidth: 420, minHeight: 420)
    }
}

private struct DirectoryTreeRow: View {
    @Bindable var node: DirectoryTreeNodeViewModel
    let selectedPath: URL
    let onSelect: (URL) -> Void

    private var isCurrent: Bool {
        node.url.standardizedFileURL.path == selectedPath.standardizedFileURL.path
    }

    var body: some View {
        DisclosureGroup(isExpanded: $node.isExpanded) {
            if let children = node.children {
                ForEach(children) { child in
                    DirectoryTreeRow(node: child, selectedPath: selectedPath, onSelect: onSelect)
                }
            } else if node.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .padding(.leading, 8)
            }
        } label: {
            HStack(spacing: 4) {
                FileIcon(type: .directory)
                Text(node.name)
                    .fontWeight(isCurrent ? .bold : .regular)
                    .foregroundStyle(isCurrent ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(isCurrent ? Color.accentColor : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .contentShape(Rectangle())
            .onTapGesture { onSelect(node.url) }
        }
        .id(node.url)
        .onChange(of: node.isExpanded) { _, expanded in
            guard expanded else { return }
            Task { await node.loadChildrenIfNeeded() }
        }
    }
}

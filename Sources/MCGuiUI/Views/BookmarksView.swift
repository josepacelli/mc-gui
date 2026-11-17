import SwiftUI

public struct BookmarkEntry: Identifiable, Hashable {
    public let id: UUID
    public let name: String
    public let path: URL

    public init(id: UUID = UUID(), name: String, path: URL) {
        self.id = id
        self.name = name
        self.path = path
    }
}

public struct BookmarksActions {
    public var list: () async throws -> [BookmarkEntry]
    public var add: (BookmarkEntry) async throws -> Void
    public var remove: (UUID) async throws -> Void

    public init(
        list: @escaping () async throws -> [BookmarkEntry] = { [] },
        add: @escaping (BookmarkEntry) async throws -> Void = { _ in },
        remove: @escaping (UUID) async throws -> Void = { _ in }
    ) {
        self.list = list
        self.add = add
        self.remove = remove
    }
}

@MainActor
@Observable
public final class BookmarksViewModel {
    private let actions: BookmarksActions
    public private(set) var bookmarks: [BookmarkEntry] = []
    public private(set) var errorMessage: String?

    public init(actions: BookmarksActions) {
        self.actions = actions
    }

    public func refresh() async {
        do {
            bookmarks = try await actions.list()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func addBookmark(for directory: URL) async {
        let entry = BookmarkEntry(name: directory.lastPathComponent, path: directory)
        do {
            try await actions.add(entry)
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
}

@MainActor
public struct BookmarksView: View {
    public let viewModel: BookmarksViewModel
    public var activeDirectory: URL
    public var onNavigate: (URL) -> Void

    public init(
        viewModel: BookmarksViewModel,
        activeDirectory: URL,
        onNavigate: @escaping (URL) -> Void = { _ in }
    ) {
        self.viewModel = viewModel
        self.activeDirectory = activeDirectory
        self.onNavigate = onNavigate
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "bookmark.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
                Text(String(localized: "bookmarks.header.title", bundle: .module, comment: "Bookmarks popover title"))
                    .font(.headline)
                Spacer()
                Button {
                    Task { await viewModel.addBookmark(for: activeDirectory) }
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .keyboardShortcut("d", modifiers: .command)
                .help(String(localized: "bookmarks.button.add.help", bundle: .module, comment: "Add-bookmark button tooltip (⌘D unchanged)"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.bar)

            Divider()

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }

            List(viewModel.bookmarks) { bookmark in
                HStack(spacing: 8) {
                    Image(systemName: "folder.fill")
                        .font(.caption)
                        .foregroundStyle(Color(nsColor: .systemBlue))
                    Button {
                        onNavigate(bookmark.path)
                    } label: {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(bookmark.name)
                                .font(.callout.weight(.medium))
                                .lineLimit(1)
                            Text(bookmark.path.path)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.head)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task { await viewModel.remove(id: bookmark.id) }
                    } label: {
                        Image(systemName: "minus.circle")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(String(localized: "bookmarks.button.remove.help", bundle: .module, comment: "Remove-bookmark button tooltip"))
                }
                .padding(.vertical, 2)
            }
            .listStyle(.inset)
        }
        .task { await viewModel.refresh() }
    }
}

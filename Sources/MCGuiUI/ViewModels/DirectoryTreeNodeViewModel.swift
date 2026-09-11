import Foundation
import Observation
import MCGuiCore

@MainActor
@Observable
public final class DirectoryTreeNodeViewModel: Identifiable {
    private let fileSystemService: FileSystemService

    public let url: URL
    public private(set) var children: [DirectoryTreeNodeViewModel]?
    public private(set) var isLoading = false
    public var isExpanded = false

    public nonisolated var id: URL { url }

    public var name: String {
        let lastComponent = url.lastPathComponent
        return lastComponent.isEmpty || lastComponent == "/" ? url.path : lastComponent
    }

    public init(url: URL, fileSystemService: FileSystemService) {
        self.url = url
        self.fileSystemService = fileSystemService
    }

    public func loadChildrenIfNeeded() async {
        guard children == nil else { return }
        isLoading = true
        let entries = (try? await fileSystemService.listDirectory(url)) ?? []
        children = entries
            .filter { $0.type == .directory && !$0.isHidden }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            .map { DirectoryTreeNodeViewModel(url: $0.path, fileSystemService: fileSystemService) }
        isLoading = false
    }

    public func expandAndLoad() async {
        isExpanded = true
        await loadChildrenIfNeeded()
    }

    public func child(at url: URL) -> DirectoryTreeNodeViewModel? {
        children?.first { $0.url.standardizedFileURL.path == url.standardizedFileURL.path }
    }
}

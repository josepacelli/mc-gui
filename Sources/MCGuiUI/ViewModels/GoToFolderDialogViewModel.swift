import Foundation
import Observation
import MCGuiCore

@MainActor
@Observable
public final class GoToFolderDialogViewModel {
    private let fileSystemService: FileSystemService

    public let root: DirectoryTreeNodeViewModel
    public let currentPath: URL
    public var path: String
    public private(set) var selectedURL: URL
    public private(set) var errorMessage: String?
    public private(set) var isCompleted = false
    public private(set) var resultPath: URL?

    public init(fileSystemService: FileSystemService, currentPath: URL, rootPath: URL = URL(fileURLWithPath: "/")) {
        self.fileSystemService = fileSystemService
        self.currentPath = currentPath
        self.path = currentPath.path
        self.selectedURL = currentPath
        self.root = DirectoryTreeNodeViewModel(url: rootPath, fileSystemService: fileSystemService)
    }

    public func selectNode(_ url: URL) {
        path = url.path
        selectedURL = url
    }

    @discardableResult
    public func expandToCurrentPath() async -> URL? {
        let rootComponents = root.url.standardizedFileURL.pathComponents
        let targetComponents = currentPath.standardizedFileURL.pathComponents
        guard targetComponents.count >= rootComponents.count,
              Array(targetComponents.prefix(rootComponents.count)) == rootComponents else { return nil }

        var node = root
        await node.expandAndLoad()
        var revealedURL = node.url

        for component in targetComponents[rootComponents.count...] {
            let childURL = node.url.appendingPathComponent(component)
            guard let child = node.child(at: childURL) else { break }
            await child.expandAndLoad()
            node = child
            revealedURL = child.url
        }

        return revealedURL
    }

    public static func resolve(_ rawPath: String) -> URL? {
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(fileURLWithPath: (trimmed as NSString).expandingTildeInPath)
    }

    public func confirm() async {
        guard let url = Self.resolve(path) else {
            errorMessage = String(localized: "goToFolder.error.empty", bundle: .module, comment: "Go to Folder dialog: path field is empty")
            return
        }

        do {
            _ = try await fileSystemService.listDirectory(url)
            errorMessage = nil
            resultPath = url
            isCompleted = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

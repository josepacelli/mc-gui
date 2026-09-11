import Foundation

public enum PanelSide: String, Codable, CaseIterable {
    case left, right
}

public struct SearchMatch: Hashable, Codable {
    public let location: Int
    public let length: Int

    public init(location: Int, length: Int) {
        self.location = location
        self.length = length
    }
}

public protocol EditorService {
    func open(_ url: URL) async throws -> EditorDocumentState

    func save(_ state: EditorDocumentState) async throws

    func close()
}

public protocol ViewerService {
    func load(_ url: URL) async throws -> ViewerContent

    func nextFile() async throws -> ViewerContent

    func previousFile() async throws -> ViewerContent

    func search(_ query: String) -> [SearchMatch]
}

public protocol TrashService {
    func trash(_ urls: [URL]) async throws -> OperationResult
}

public protocol PathHistoryStore {
    func save(_ history: PanelPathHistory, for panel: PanelSide) async throws

    func load(for panel: PanelSide) async throws -> PanelPathHistory
}

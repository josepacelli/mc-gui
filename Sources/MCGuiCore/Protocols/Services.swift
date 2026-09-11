import Foundation

// SPEC_DEVIATION: `PanelSide` is not among the 13 domain models spec.md's SWIFT-02
// enumerates (it first appears as a `Reuses` citation in T17, Phase 4), but design.md's
// PathHistoryStoreImpl Key Methods require it as a parameter type for `save`/`load`.
// Defined here as the minimal supporting type needed for the protocol signature to
// compile; left/right cases match the C# reference (`PanelSide.cs`).
/// Identifies which of the two panels a value belongs to.
public enum PanelSide: String, Codable, CaseIterable {
    case left, right
}

/// A single text-search match within viewer content.
public struct SearchMatch: Hashable, Codable {
    public let location: Int
    public let length: Int

    public init(location: Int, length: Int) {
        self.location = location
        self.length = length
    }
}

/// Loading, saving, and closing a text editor document.
public protocol EditorService {
    func open(_ url: URL) async throws -> EditorDocumentState

    func save(_ state: EditorDocumentState) async throws

    func close()
}

/// Loading file content for the viewer, navigating between files, and searching.
public protocol ViewerService {
    func load(_ url: URL) async throws -> ViewerContent

    func nextFile() async throws -> ViewerContent

    func previousFile() async throws -> ViewerContent

    func search(_ query: String) -> [SearchMatch]
}

/// Moving files to the system Trash.
public protocol TrashService {
    func trash(_ urls: [URL]) async throws -> OperationResult
}

/// Persisting and loading per-panel navigation history.
public protocol PathHistoryStore {
    func save(_ history: PanelPathHistory, for panel: PanelSide) async throws

    func load(for panel: PanelSide) async throws -> PanelPathHistory
}

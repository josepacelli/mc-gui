import Foundation

/// The user's chosen resolution for a destination-already-exists conflict.
public enum FileConflictResolution: String, Codable, CaseIterable {
    case overwrite, skip, rename, cancel
}

/// The current state of an open text editor document.
public struct EditorDocumentState: Codable, Hashable {
    public var content: String
    public var fileURL: URL
    public var isDirty: Bool
    public var encoding: String

    public init(content: String, fileURL: URL, isDirty: Bool, encoding: String) {
        self.content = content
        self.fileURL = fileURL
        self.isDirty = isDirty
        self.encoding = encoding
    }
}

// SPEC_DEVIATION: `ViewerMode` is not among the 13 domain models spec.md's SWIFT-02
// enumerates, but design.md's ViewerState bullet ("mode (text/image/hex)") requires a
// type for that field. Defined here, alongside ViewerState, as the minimal supporting
// type needed for ViewerState to compile.
/// Which representation the file viewer is currently displaying.
public enum ViewerMode: String, Codable, CaseIterable {
    case text, image, hex
}

/// The content loaded into the file viewer, in one of its supported representations.
public enum ViewerContent: Codable, Hashable {
    case text(String)
    case image(Data)
    case hexData(Data)
}

/// The current state of an open file viewer.
public struct ViewerState: Codable {
    public var mode: ViewerMode
    public var content: ViewerContent?
    public var scrollPosition: Double
    public var searchQuery: String?

    public init(mode: ViewerMode, content: ViewerContent?, scrollPosition: Double, searchQuery: String?) {
        self.mode = mode
        self.content = content
        self.scrollPosition = scrollPosition
        self.searchQuery = searchQuery
    }
}

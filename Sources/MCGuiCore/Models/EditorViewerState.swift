import Foundation

public enum FileConflictResolution: String, Codable, CaseIterable {
    case overwrite, skip, rename, cancel
}

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

public enum ViewerMode: String, Codable, CaseIterable {
    case text, image, hex
}

public enum ViewerContent: Codable, Hashable {
    case text(String)
    case image(Data)
    case hexData(Data)
}

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

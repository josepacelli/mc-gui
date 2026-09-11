import Foundation
import Observation
import MCGuiCore

@MainActor
@Observable
public final class EditorWindowViewModel {
    private let editorService: EditorService
    public let fileURL: URL
    private let encoding: String

    public var content: String {
        didSet {
            guard content != oldValue else { return }
            isDirty = true
        }
    }

    public private(set) var isDirty: Bool
    public private(set) var errorMessage: String?
    public private(set) var isClosed = false

    public init(editorService: EditorService, document: EditorDocumentState) {
        self.editorService = editorService
        self.fileURL = document.fileURL
        self.encoding = document.encoding
        self.content = document.content
        self.isDirty = document.isDirty
    }

    public func save() async {
        do {
            try await editorService.save(EditorDocumentState(content: content, fileURL: fileURL, isDirty: isDirty, encoding: encoding))
            isDirty = false
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func attemptClose() -> Bool {
        guard isDirty else {
            isClosed = true
            return true
        }
        return false
    }

    public func saveAndClose() async {
        await save()
        guard errorMessage == nil else { return }
        isClosed = true
    }

    public func discardAndClose() {
        isClosed = true
    }
}

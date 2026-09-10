import Foundation
import Observation
import MCGuiCore

/// Editor window state for one open document: dirty tracking and the save/close flow
/// (ED-03, ED-05..ED-08), backed by an injected `EditorService`.
///
// SPEC_DEVIATION (T40): design.md's Reuses cites both `EditorWindowViewModel.cs` (a
// multi-tab container) and `EditorTabViewModel.cs` (per-tab dirty tracking), but neither
// spec.md's ED-01..ED-10 nor design.md's ViewModels list (line 184: "EditorWindowViewModel
// - Editor state, dirty tracking, save") calls for tabs - F4 opens one editor per file
// (ED-01), with no multi-document/tab requirement anywhere in scope. Ported here as a
// single-document ViewModel combining both C# classes' dirty-tracking/save responsibility,
// consistent with this batch's simplicity directive and the shape of the sibling Phase 5
// dialog ViewModels (also single-purpose, no collection-of-tabs wrapper).
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

    /// Writes `content` back to disk via the injected `EditorService` (ED-04) and clears
    /// the dirty flag on success. On failure, `isDirty` stays set and `errorMessage`
    /// reports the reason.
    public func save() async {
        do {
            try await editorService.save(EditorDocumentState(content: content, fileURL: fileURL, isDirty: isDirty, encoding: encoding))
            isDirty = false
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Attempts to close the editor (ED-05). With no unsaved changes, closes immediately
    /// and returns `true`. With unsaved changes, does nothing and returns `false` - the
    /// caller (`EditorWindow`, T43) is expected to present the save-changes prompt
    /// (`SaveChangesDialogViewModel`/`SaveChangesDialog`, T41/T42) and resolve it via
    /// `saveAndClose()`/`discardAndClose()`.
    public func attemptClose() -> Bool {
        guard isDirty else {
            isClosed = true
            return true
        }
        return false
    }

    /// Applies a "Save" choice from the save-changes prompt (ED-06): saves, then closes
    /// only if the save succeeded.
    public func saveAndClose() async {
        await save()
        guard errorMessage == nil else { return }
        isClosed = true
    }

    /// Applies a "Don't Save" choice from the save-changes prompt (ED-07): closes without
    /// writing any changes to disk.
    public func discardAndClose() {
        isClosed = true
    }
}

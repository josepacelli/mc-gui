import Foundation
import Testing
@testable import MCGuiUI
import MCGuiCore

@Suite("EditorWindowViewModel")
@MainActor
struct EditorWindowViewModelTests {

    private let fileURL = URL(fileURLWithPath: "/tmp/doc.txt")

    private func makeDocument(content: String = "original") -> EditorDocumentState {
        EditorDocumentState(content: content, fileURL: fileURL, isDirty: false, encoding: "UTF-8")
    }


    @Test("setting content to a different value marks the document dirty")
    func editingContentSetsDirty() {
        let viewModel = EditorWindowViewModel(editorService: MockEditorService(), document: makeDocument())

        viewModel.content = "changed"

        #expect(viewModel.isDirty == true)
    }

    @Test("setting content to the same value does not mark the document dirty")
    func settingSameContentDoesNotSetDirty() {
        let viewModel = EditorWindowViewModel(editorService: MockEditorService(), document: makeDocument(content: "same"))

        viewModel.content = "same"

        #expect(viewModel.isDirty == false)
    }


    @Test("save clears the dirty flag after a successful write")
    func saveClearsDirtyFlag() async {
        final class Recorder { var saved: EditorDocumentState? }
        let recorder = Recorder()
        let service = MockEditorService(saveImpl: { state in recorder.saved = state })
        let viewModel = EditorWindowViewModel(editorService: service, document: makeDocument())
        viewModel.content = "edited"
        #expect(viewModel.isDirty == true)

        await viewModel.save()

        #expect(viewModel.isDirty == false)
        #expect(viewModel.errorMessage == nil)
        #expect(recorder.saved?.content == "edited")
        #expect(recorder.saved?.fileURL == fileURL)
    }

    @Test("save on failure sets errorMessage and leaves the dirty flag set")
    func saveFailureSetsErrorAndKeepsDirty() async {
        let service = MockEditorService(saveImpl: { _ in throw MockError(message: "disk full") })
        let viewModel = EditorWindowViewModel(editorService: service, document: makeDocument())
        viewModel.content = "edited"

        await viewModel.save()

        #expect(viewModel.isDirty == true)
        #expect(viewModel.errorMessage == "disk full")
    }


    @Test("attemptClose with no unsaved changes closes immediately and skips the save prompt")
    func attemptCloseWithNoChangesClosesImmediately() {
        let viewModel = EditorWindowViewModel(editorService: MockEditorService(), document: makeDocument())

        let closedDirectly = viewModel.attemptClose()

        #expect(closedDirectly == true)
        #expect(viewModel.isClosed == true)
    }

    @Test("attemptClose with unsaved changes does not close and signals the save prompt is needed")
    func attemptCloseWithUnsavedChangesRequiresPrompt() {
        let viewModel = EditorWindowViewModel(editorService: MockEditorService(), document: makeDocument())
        viewModel.content = "changed"

        let closedDirectly = viewModel.attemptClose()

        #expect(closedDirectly == false)
        #expect(viewModel.isClosed == false)
    }

    @Test("saveAndClose saves then closes on success (ED-06)")
    func saveAndCloseSavesThenCloses() async {
        let service = MockEditorService()
        let viewModel = EditorWindowViewModel(editorService: service, document: makeDocument())
        viewModel.content = "changed"

        await viewModel.saveAndClose()

        #expect(viewModel.isDirty == false)
        #expect(viewModel.isClosed == true)
    }

    @Test("saveAndClose leaves the editor open when the save fails")
    func saveAndCloseKeepsOpenOnSaveFailure() async {
        let service = MockEditorService(saveImpl: { _ in throw MockError(message: "disk full") })
        let viewModel = EditorWindowViewModel(editorService: service, document: makeDocument())
        viewModel.content = "changed"

        await viewModel.saveAndClose()

        #expect(viewModel.isClosed == false)
        #expect(viewModel.errorMessage == "disk full")
    }

    @Test("discardAndClose closes without saving (ED-07)")
    func discardAndCloseClosesWithoutSaving() {
        final class Recorder { var callCount = 0 }
        let recorder = Recorder()
        let service = MockEditorService(saveImpl: { _ in recorder.callCount += 1 })
        let viewModel = EditorWindowViewModel(editorService: service, document: makeDocument())
        viewModel.content = "changed"

        viewModel.discardAndClose()

        #expect(viewModel.isClosed == true)
        #expect(recorder.callCount == 0)
    }
}

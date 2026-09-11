import Foundation
import Testing
@testable import MCGuiUI
import MCGuiCore

@Suite("ViewerViewModel")
@MainActor
struct ViewerViewModelTests {


    @Test("load with text content sets mode to .text")
    func loadTextContentSetsTextMode() async {
        let service = MockViewerService(loadImpl: { _ in .text("hello") })
        let viewModel = ViewerViewModel(viewerService: service)

        await viewModel.load(URL(fileURLWithPath: "/tmp/a.txt"))

        #expect(viewModel.content == .text("hello"))
        #expect(viewModel.mode == .text)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("load with image content sets mode to .image")
    func loadImageContentSetsImageMode() async {
        let imageData = Data([0x01, 0x02])
        let service = MockViewerService(loadImpl: { _ in .image(imageData) })
        let viewModel = ViewerViewModel(viewerService: service)

        await viewModel.load(URL(fileURLWithPath: "/tmp/a.png"))

        #expect(viewModel.content == .image(imageData))
        #expect(viewModel.mode == .image)
    }

    @Test("load with binary content sets mode to .hex")
    func loadBinaryContentSetsHexMode() async {
        let binaryData = Data([0x00, 0xFF])
        let service = MockViewerService(loadImpl: { _ in .hexData(binaryData) })
        let viewModel = ViewerViewModel(viewerService: service)

        await viewModel.load(URL(fileURLWithPath: "/tmp/a.bin"))

        #expect(viewModel.content == .hexData(binaryData))
        #expect(viewModel.mode == .hex)
    }


    @Test("setMode to .hex on already-loaded text content derives hex bytes without another ViewerService call")
    func setModeToHexOnTextContentDerivesRawDataWithoutReload() async {
        final class Recorder { var loadCallCount = 0 }
        let recorder = Recorder()
        let service = MockViewerService(loadImpl: { _ in
            recorder.loadCallCount += 1
            return .text("hi")
        })
        let viewModel = ViewerViewModel(viewerService: service)
        await viewModel.load(URL(fileURLWithPath: "/tmp/a.txt"))
        #expect(recorder.loadCallCount == 1)

        viewModel.setMode(.hex)

        #expect(viewModel.mode == .hex)
        #expect(viewModel.rawData == Data("hi".utf8))
        #expect(recorder.loadCallCount == 1)
    }

    @Test("setMode back to .text after switching to .hex restores the text mode")
    func setModeBackToTextRestoresTextMode() async {
        let service = MockViewerService(loadImpl: { _ in .text("hi") })
        let viewModel = ViewerViewModel(viewerService: service)
        await viewModel.load(URL(fileURLWithPath: "/tmp/a.txt"))
        viewModel.setMode(.hex)

        viewModel.setMode(.text)

        #expect(viewModel.mode == .text)
    }


    @Test("next loads the following file via ViewerService.nextFile")
    func nextLoadsFollowingFile() async {
        let service = MockViewerService(nextFileImpl: { .text("next-content") })
        let viewModel = ViewerViewModel(viewerService: service)

        await viewModel.next()

        #expect(viewModel.content == .text("next-content"))
        #expect(viewModel.errorMessage == nil)
    }

    @Test("previous loads the preceding file via ViewerService.previousFile")
    func previousLoadsPrecedingFile() async {
        let service = MockViewerService(previousFileImpl: { .text("previous-content") })
        let viewModel = ViewerViewModel(viewerService: service)

        await viewModel.previous()

        #expect(viewModel.content == .text("previous-content"))
        #expect(viewModel.errorMessage == nil)
    }


    @Test("setting searchQuery with matches populates searchMatches and scrolls to the first match")
    func searchWithMatchesScrollsToFirstMatch() async {
        let matches = [SearchMatch(location: 12, length: 3), SearchMatch(location: 40, length: 3)]
        let service = MockViewerService(
            loadImpl: { _ in .text("some text containing fox twice: fox") },
            searchImpl: { _ in matches }
        )
        let viewModel = ViewerViewModel(viewerService: service)
        await viewModel.load(URL(fileURLWithPath: "/tmp/a.txt"))

        viewModel.searchQuery = "fox"

        #expect(viewModel.searchMatches == matches)
        #expect(viewModel.scrollPosition == 12)
    }

    @Test("setting searchQuery with zero matches clears searchMatches and does not move scrollPosition")
    func searchWithZeroMatchesDoesNotScroll() async {
        let service = MockViewerService(
            loadImpl: { _ in .text("no matches here") },
            searchImpl: { _ in [] }
        )
        let viewModel = ViewerViewModel(viewerService: service)
        await viewModel.load(URL(fileURLWithPath: "/tmp/a.txt"))
        viewModel.scrollPosition = 99

        viewModel.searchQuery = "zzz"

        #expect(viewModel.searchMatches == [])
        #expect(viewModel.scrollPosition == 99)
    }

    @Test("clearing searchQuery clears searchMatches")
    func clearingSearchQueryClearsMatches() async {
        let matches = [SearchMatch(location: 0, length: 3)]
        let service = MockViewerService(
            loadImpl: { _ in .text("fox") },
            searchImpl: { _ in matches }
        )
        let viewModel = ViewerViewModel(viewerService: service)
        await viewModel.load(URL(fileURLWithPath: "/tmp/a.txt"))
        viewModel.searchQuery = "fox"
        #expect(viewModel.searchMatches == matches)

        viewModel.searchQuery = ""

        #expect(viewModel.searchMatches == [])
    }


    @Test("load failure sets errorMessage and leaves content unchanged")
    func loadFailureSetsErrorMessage() async {
        let service = MockViewerService(loadImpl: { _ in throw MockError(message: "cannot read file") })
        let viewModel = ViewerViewModel(viewerService: service)

        await viewModel.load(URL(fileURLWithPath: "/tmp/missing.txt"))

        #expect(viewModel.errorMessage == "cannot read file")
        #expect(viewModel.content == nil)
        #expect(viewModel.isLoading == false)
    }

    @Test("next failure sets errorMessage and leaves previously loaded content unchanged")
    func nextFailureSetsErrorMessageAndKeepsPreviousContent() async {
        var shouldFail = false
        let service = MockViewerService(
            loadImpl: { _ in .text("original") },
            nextFileImpl: {
                if shouldFail { throw MockError(message: "no navigation context") }
                return .text("original")
            }
        )
        let viewModel = ViewerViewModel(viewerService: service)
        await viewModel.load(URL(fileURLWithPath: "/tmp/a.txt"))
        shouldFail = true

        await viewModel.next()

        #expect(viewModel.errorMessage == "no navigation context")
        #expect(viewModel.content == .text("original"))
    }
}

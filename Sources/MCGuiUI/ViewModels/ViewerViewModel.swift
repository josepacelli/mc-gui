import Foundation
import Observation
import MCGuiCore

/// The file viewer's state: loaded content, the active display mode (text/image/hex),
/// next/previous navigation, and text search - backed by an injected `ViewerService`
/// (FV-01..FV-06, FV-08).
@MainActor
@Observable
public final class ViewerViewModel {
    private let viewerService: ViewerService

    public private(set) var mode: ViewerMode = .text
    public private(set) var content: ViewerContent?
    public private(set) var errorMessage: String?
    public private(set) var isLoading = false

    public var scrollPosition: Double = 0
    public private(set) var searchMatches: [SearchMatch] = []

    public var searchQuery: String = "" {
        didSet {
            guard searchQuery != oldValue else { return }
            updateSearchMatches()
        }
    }

    public init(viewerService: ViewerService) {
        self.viewerService = viewerService
    }

    /// The currently loaded content's raw bytes, regardless of `mode`: a text file's
    /// UTF-8 bytes, or an already-binary file's bytes as-is. Lets `mode` switch to `.hex`
    /// on a text file (or vice versa is not attempted, per FV-04 - hex mode always has
    /// bytes to show) without calling back into `ViewerService`.
    public var rawData: Data? {
        switch content {
        case .text(let text): return Data(text.utf8)
        case .image(let data), .hexData(let data): return data
        case .none: return nil
        }
    }

    /// Loads `url` via the injected `ViewerService` (FV-01, FV-02, FV-03, FV-04). On
    /// failure (FV-08), leaves the previously displayed `content`/`mode` in place and
    /// surfaces the failure reason via `errorMessage`.
    public func load(_ url: URL) async {
        await run { try await viewerService.load(url) }
    }

    /// Loads the next file in the panel's file list (FV-05).
    public func next() async {
        await run { try await viewerService.nextFile() }
    }

    /// Loads the previous file in the panel's file list (FV-05).
    public func previous() async {
        await run { try await viewerService.previousFile() }
    }

    /// Switches which representation of the already-loaded content is displayed (the
    /// Text/Image/Hex mode tabs, FV-01). Never calls back into `ViewerService` - the
    /// alternate representation is derived from `rawData`, so switching tabs never
    /// re-reads the file from disk.
    public func setMode(_ newMode: ViewerMode) {
        mode = newMode
    }

    private func run(_ operation: () async throws -> ViewerContent) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await operation()
            content = loaded
            errorMessage = nil
            mode = Self.defaultMode(for: loaded)
            scrollPosition = 0
            updateSearchMatches()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Re-runs `ViewerService.search` for `searchQuery` against the currently loaded
    /// content and scrolls to the first match, if any (FV-06).
    private func updateSearchMatches() {
        searchMatches = searchQuery.isEmpty ? [] : viewerService.search(searchQuery)
        if let first = searchMatches.first {
            scrollPosition = Double(first.location)
        }
    }

    private static func defaultMode(for content: ViewerContent) -> ViewerMode {
        switch content {
        case .text: return .text
        case .image: return .image
        case .hexData: return .hex
        }
    }
}

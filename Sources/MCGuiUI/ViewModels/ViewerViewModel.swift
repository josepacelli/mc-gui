import Foundation
import Observation
import MCGuiCore

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

    public var rawData: Data? {
        switch content {
        case .text(let text): return Data(text.utf8)
        case .image(let data), .hexData(let data): return data
        case .none: return nil
        }
    }

    public func load(_ url: URL) async {
        await run { try await viewerService.load(url) }
    }

    public func next() async {
        await run { try await viewerService.nextFile() }
    }

    public func previous() async {
        await run { try await viewerService.previousFile() }
    }

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

import Foundation
import AppKit
import MCGuiCore

/// Typed errors `ViewerServiceImpl` can throw, per design.md's Error Handling Strategy.
public enum ViewerServiceError: Error, Equatable {
    /// The file could not be opened for reading (FV-08): missing, permission denied, or
    /// not a regular file.
    case cannotRead(URL)
    /// `nextFile()`/`previousFile()` was called before `load(_:)` established a
    /// navigation position, or with no file list set via `setFileList(_:)`.
    case noNavigationContext
}

/// macOS `ViewerService` implementation: text/hex/image loading (T34, T35), panel
/// navigation (`nextFile`/`previousFile`, T35), and text search (T35).
///
/// Text is read in fixed-size chunks (`chunkSize`, default 1MB) rather than one single
/// blocking read, yielding to the cooperative thread pool between chunks (FV-07: files up
/// to 100MB must not block the UI). The type is not `@MainActor`-isolated, so awaiting
/// `load(_:)` from a `@MainActor` caller (e.g. `ViewerViewModel`, T37) already hops off the
/// main actor for the duration of the read.
public final class ViewerServiceImpl {
    private let chunkSize: Int
    private let binaryDetectionSampleSize: Int
    private let openForReading: (URL) throws -> FileHandle
    private let readChunk: (FileHandle, Int) -> Data

    // MARK: - Navigation/search state (T35)

    // SPEC_DEVIATION (T35): `ViewerService.nextFile()`/`previousFile()` (frozen, Phase 1)
    // take no parameters, so the navigable file list can't be passed per-call. Design.md
    // doesn't specify how the service learns "the panel's file list" either. Exposed here
    // as `setFileList(_:)` - a method on the concrete type, not the protocol - for a
    // caller (e.g. `ViewerViewModel`, T37) to provide the panel's current entries when the
    // viewer opens.
    private var fileList: [URL] = []
    private var currentIndex: Int?
    /// The most recently loaded `.text` content, kept for `search(_:)` (FV-06). `nil`
    /// after loading an image or hex file - searching a file not in text mode finds
    /// nothing.
    private var currentText: String?

    /// - Parameters:
    ///   - chunkSize: Bytes read per iteration while loading a file's contents.
    ///   - binaryDetectionSampleSize: How many leading bytes to inspect for a NUL byte
    ///     when deciding text vs. hex mode (mirrors `MacViewerService`'s 8KB sample).
    ///   - openForReading, readChunk: Injectable seams over `FileHandle`, defaulting to
    ///     the real APIs. Tests use these to simulate an unopenable file (FV-08) and to
    ///     observe that a large read happens over multiple chunks rather than one.
    public init(
        chunkSize: Int = 1_048_576,
        binaryDetectionSampleSize: Int = 8192,
        openForReading: ((URL) throws -> FileHandle)? = nil,
        readChunk: ((FileHandle, Int) -> Data)? = nil
    ) {
        self.chunkSize = chunkSize
        self.binaryDetectionSampleSize = binaryDetectionSampleSize
        self.openForReading = openForReading ?? { url in try FileHandle(forReadingFrom: url) }
        self.readChunk = readChunk ?? { handle, size in handle.readData(ofLength: size) }
    }

    // MARK: - load

    /// Loads `url`'s contents as image, text, or hex (FV-02, FV-03, FV-04): image data
    /// (decodable by `NSImage`) loads as `.image`; otherwise binary content (a NUL byte
    /// within the first `binaryDetectionSampleSize` bytes) loads as `.hexData`; otherwise
    /// as `.text`, decoding UTF-8 first and falling back to Latin-1 (always succeeds) so a
    /// non-UTF-8, non-binary file still renders as text rather than erroring.
    ///
    /// Also updates the navigation position for `nextFile()`/`previousFile()`: when `url`
    /// is present in the list given to `setFileList(_:)`, that becomes the current index.
    public func load(_ url: URL) async throws -> ViewerContent {
        let handle: FileHandle
        do {
            handle = try openForReading(url)
        } catch {
            throw ViewerServiceError.cannotRead(url)
        }
        defer { try? handle.close() }

        let data = try await readAllChunked(handle)
        currentIndex = fileList.firstIndex(of: url)

        if data.isEmpty {
            currentText = ""
            return .text("")
        }

        if NSImage(data: data) != nil {
            currentText = nil
            return .image(data)
        }

        if Self.isBinary(data.prefix(binaryDetectionSampleSize)) {
            currentText = nil
            return .hexData(data)
        }

        if let text = String(data: data, encoding: .utf8) {
            currentText = text
            return .text(text)
        }
        if let text = String(data: data, encoding: .isoLatin1) {
            currentText = text
            return .text(text)
        }
        currentText = nil
        return .hexData(data)
    }

    // MARK: - navigation (T35, FV-05)

    /// Sets the ordered list of files the panel is currently showing, used by
    /// `nextFile()`/`previousFile()` to know what comes before/after the loaded file.
    public func setFileList(_ urls: [URL]) {
        fileList = urls
    }

    /// Loads the file after the currently loaded one. Stops at the last file - calling
    /// this again at the end re-loads (and returns) that same last file rather than
    /// wrapping around or erroring, since neither spec.md nor design.md specifies
    /// wrap-around behavior.
    public func nextFile() async throws -> ViewerContent {
        try await move(by: 1)
    }

    /// Loads the file before the currently loaded one. Stops at the first file,
    /// symmetric with `nextFile()`.
    public func previousFile() async throws -> ViewerContent {
        try await move(by: -1)
    }

    private func move(by delta: Int) async throws -> ViewerContent {
        guard let index = currentIndex else {
            throw ViewerServiceError.noNavigationContext
        }
        let targetIndex = fileList.indices.contains(index + delta) ? index + delta : index
        return try await load(fileList[targetIndex])
    }

    // MARK: - search (T35, FV-06)

    /// Finds every case-insensitive occurrence of `query` in the most recently loaded
    /// text content. Returns an empty array for an empty query, no loaded text (image/hex
    /// mode or nothing loaded yet), or zero matches.
    public func search(_ query: String) -> [SearchMatch] {
        guard let text = currentText, !query.isEmpty else { return [] }

        let haystack = text as NSString
        var matches: [SearchMatch] = []
        var searchRange = NSRange(location: 0, length: haystack.length)

        while searchRange.length > 0 {
            let found = haystack.range(of: query, options: .caseInsensitive, range: searchRange)
            guard found.location != NSNotFound else { break }
            matches.append(SearchMatch(location: found.location, length: found.length))
            let nextLocation = found.location + found.length
            searchRange = NSRange(location: nextLocation, length: haystack.length - nextLocation)
        }

        return matches
    }

    /// Reads `handle` to EOF in `chunkSize`-sized pieces, yielding to the cooperative
    /// thread pool between chunks so a large read stays responsive (FV-07).
    private func readAllChunked(_ handle: FileHandle) async throws -> Data {
        var result = Data()
        while true {
            let chunk = readChunk(handle, chunkSize)
            if chunk.isEmpty { break }
            result.append(chunk)
            await Task.yield()
        }
        return result
    }

    /// A sample containing a NUL byte is treated as binary, mirroring
    /// `MacViewerService`'s detection heuristic.
    static func isBinary<D: DataProtocol>(_ sample: D) -> Bool {
        sample.contains(0)
    }
}

extension ViewerServiceImpl: ViewerService {}

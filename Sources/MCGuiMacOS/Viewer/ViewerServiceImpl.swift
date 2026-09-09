import Foundation
import MCGuiCore

/// Typed errors `ViewerServiceImpl` can throw, per design.md's Error Handling Strategy.
public enum ViewerServiceError: Error, Equatable {
    /// The file could not be opened for reading (FV-08): missing, permission denied, or
    /// not a regular file.
    case cannotRead(URL)
}

/// macOS `ViewerService` implementation. This file covers text/hex loading (T34); image
/// loading, panel navigation (`nextFile`/`previousFile`), and `search` are added in T35.
///
/// Text is read in fixed-size chunks (`chunkSize`, default 1MB) rather than one single
/// blocking read, yielding to the cooperative thread pool between chunks (FV-07: files up
/// to 100MB must not block the UI). The type is not `@MainActor`-isolated, so awaiting
/// `load(_:)` from a `@MainActor` caller (e.g. a future `ViewerViewModel`, T37) already
/// hops off the main actor for the duration of the read.
public final class ViewerServiceImpl {
    private let chunkSize: Int
    private let binaryDetectionSampleSize: Int
    private let openForReading: (URL) throws -> FileHandle
    private let readChunk: (FileHandle, Int) -> Data

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

    /// Loads `url`'s contents as text or hex (FV-02, FV-04). Binary content (a NUL byte
    /// within the first `binaryDetectionSampleSize` bytes) loads as `.hexData`; otherwise
    /// as `.text`, decoding UTF-8 first and falling back to Latin-1 (always succeeds) so a
    /// non-UTF-8, non-binary file still renders as text rather than erroring.
    public func load(_ url: URL) async throws -> ViewerContent {
        let handle: FileHandle
        do {
            handle = try openForReading(url)
        } catch {
            throw ViewerServiceError.cannotRead(url)
        }
        defer { try? handle.close() }

        let data = try await readAllChunked(handle)
        if data.isEmpty {
            return .text("")
        }

        if Self.isBinary(data.prefix(binaryDetectionSampleSize)) {
            return .hexData(data)
        }

        if let text = String(data: data, encoding: .utf8) {
            return .text(text)
        }
        if let text = String(data: data, encoding: .isoLatin1) {
            return .text(text)
        }
        return .hexData(data)
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

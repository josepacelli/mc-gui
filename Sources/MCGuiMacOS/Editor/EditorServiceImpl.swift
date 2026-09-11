import Foundation
import MCGuiCore

/// Typed errors `EditorServiceImpl` can throw, per design.md's Error Handling Strategy
/// (mirrors `ViewerServiceError`/`FileSystemServiceError`'s pattern of typed, `Equatable`
/// errors instead of raw `NSError`/`CocoaError`).
public enum EditorServiceError: Error, Equatable {
    /// The file could not be opened for reading: missing, permission denied, or not a
    /// regular file.
    case cannotRead(URL)
    /// The file could not be written: permission denied or an unwritable path.
    case cannotWrite(URL)
}

/// macOS `EditorService` implementation (T39): loads a file's content into an
/// `EditorDocumentState` with detected encoding, and writes edited content back to disk.
///
/// Reuses `MacEditorService.cs`'s BOM-aware UTF-8 detection: a leading UTF-8 BOM is
/// stripped and reported as "UTF-8 BOM"; otherwise content decodes as UTF-8 ("UTF-8"),
/// falling back to Latin-1 ("Latin-1") for non-UTF-8 bytes (Latin-1 has no invalid byte
/// sequences, so this always succeeds rather than erroring on unusual encodings). Saving
/// always writes UTF-8 without a BOM, regardless of the encoding content was loaded with -
/// same behavior as `MacEditorService.SaveAsync`.
public final class EditorServiceImpl {
    private static let utf8Bom: [UInt8] = [0xEF, 0xBB, 0xBF]

    public init() {}

    /// Loads `url`'s contents (ED-01, ED-02).
    public func open(_ url: URL) async throws -> EditorDocumentState {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw EditorServiceError.cannotRead(url)
        }

        if data.isEmpty {
            return EditorDocumentState(content: "", fileURL: url, isDirty: false, encoding: "UTF-8")
        }

        var bytes = data
        var encoding = "UTF-8"
        if data.count >= Self.utf8Bom.count, Array(data.prefix(Self.utf8Bom.count)) == Self.utf8Bom {
            bytes = data.dropFirst(Self.utf8Bom.count)
            encoding = "UTF-8 BOM"
        }

        if let text = String(data: bytes, encoding: .utf8) {
            return EditorDocumentState(content: text, fileURL: url, isDirty: false, encoding: encoding)
        }

        let text = String(data: bytes, encoding: .isoLatin1) ?? ""
        return EditorDocumentState(content: text, fileURL: url, isDirty: false, encoding: "Latin-1")
    }

    /// Writes `state.content` back to `state.fileURL` as UTF-8 (ED-04).
    public func save(_ state: EditorDocumentState) async throws {
        do {
            try Data(state.content.utf8).write(to: state.fileURL)
        } catch {
            throw EditorServiceError.cannotWrite(state.fileURL)
        }
    }

    public func close() {}
}

extension EditorServiceImpl: EditorService {}

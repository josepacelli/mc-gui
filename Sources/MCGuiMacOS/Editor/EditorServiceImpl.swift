import Foundation
import MCGuiCore

public enum EditorServiceError: Error, Equatable {
    case cannotRead(URL)
    case cannotWrite(URL)
}

public final class EditorServiceImpl {
    private static let utf8Bom: [UInt8] = [0xEF, 0xBB, 0xBF]

    public init() {}

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

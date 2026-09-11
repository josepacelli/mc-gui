import Foundation
import Observation
import MCGuiCore

public enum MkdirValidationError: LocalizedError, Equatable {
    case empty
    case containsPathSeparator

    public var errorDescription: String? {
        switch self {
        case .empty: return String(localized: "mkdirValidation.error.empty", bundle: .module, comment: "F7 dialog: the new-folder name field is empty")
        case .containsPathSeparator: return String(localized: "mkdirValidation.error.containsSlash", bundle: .module, comment: "F7 dialog: the new-folder name contains a path separator")
        }
    }
}

@MainActor
@Observable
public final class MkdirDialogViewModel {
    private let fileSystemService: FileSystemService
    public let parentDirectory: URL

    public var name: String = ""
    public private(set) var errorMessage: String?
    public private(set) var isCompleted = false

    public init(fileSystemService: FileSystemService, parentDirectory: URL) {
        self.fileSystemService = fileSystemService
        self.parentDirectory = parentDirectory
    }

    public static func validate(_ name: String) -> MkdirValidationError? {
        if name.isEmpty { return .empty }
        if name.contains("/") { return .containsPathSeparator }
        return nil
    }

    public func confirm() async {
        if let validationError = Self.validate(name) {
            errorMessage = validationError.errorDescription
            return
        }

        errorMessage = nil
        do {
            try await fileSystemService.createDirectory(parentDirectory.appendingPathComponent(name))
            isCompleted = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

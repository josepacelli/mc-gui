import Foundation
import Observation
import MCGuiCore

/// A reason a candidate new-folder name was rejected (FO-10/FO-11).
public enum MkdirValidationError: LocalizedError, Equatable {
    case empty
    case containsPathSeparator

    public var errorDescription: String? {
        switch self {
        case .empty: return "Folder name cannot be empty."
        case .containsPathSeparator: return "Folder name cannot contain \"/\"."
        }
    }
}

/// New-folder-name input state for the F7 dialog: validates `name`, then creates the
/// directory via the injected `FileSystemService` on confirm (FO-10, FO-11).
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

    /// Validates a candidate folder name; `nil` means valid. Exposed as `static` so views
    /// (e.g. to disable a Create button) can check validity without triggering `confirm()`.
    public static func validate(_ name: String) -> MkdirValidationError? {
        if name.isEmpty { return .empty }
        if name.contains("/") { return .containsPathSeparator }
        return nil
    }

    /// Validates `name` and, if valid, creates the directory (FO-11). An invalid name is
    /// rejected with `errorMessage` set and no filesystem call is made, so the dialog stays
    /// open (FO-10).
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

import Foundation
import Testing
@testable import MCGuiMacOS

@Suite("FileSystemServiceError localization (I18N-01..04, T5)")
struct FileSystemServiceErrorLocalizationTests {

    private static let path = "/Users/test/Documents/report.txt"
    private static let url = URL(fileURLWithPath: path)

    private static func table(for language: String) -> [String: String] {
        let lprojPath = Bundle.module.path(forResource: language, ofType: "lproj")
            ?? Bundle.module.path(forResource: language.lowercased(), ofType: "lproj")
        guard let lprojPath,
              let bundle = Bundle(path: lprojPath),
              let stringsPath = bundle.path(forResource: "Localizable", ofType: "strings"),
              let dict = NSDictionary(contentsOfFile: stringsPath) as? [String: String]
        else {
            Issue.record("Missing or unreadable \(language).lproj/Localizable.strings in MCGuiMacOS's resource bundle")
            return [:]
        }
        return dict
    }

    private static func message(_ key: String, language: String, _ args: CVarArg...) -> String {
        let format = Self.table(for: language)[key] ?? "MISSING_KEY:\(key)"
        return String(format: format, arguments: args)
    }

    private static let languages = ["en", "pt-BR", "pt-PT", "es"]

    private static let permissionDeniedExpected: [String: String] = [
        "en": "Permission denied: “\(path)”.",
        "pt-BR": "Permissão negada: “\(path)”.",
        "pt-PT": "Permissão negada: “\(path)”.",
        "es": "Permiso denegado: “\(path)”.",
    ]

    private static let alreadyExistsExpected: [String: String] = [
        "en": "“\(path)” already exists.",
        "pt-BR": "“\(path)” já existe.",
        "pt-PT": "“\(path)” já existe.",
        "es": "“\(path)” ya existe.",
    ]

    private static let fileInUseExpected: [String: String] = [
        "en": "“\(path)” is in use by another process.",
        "pt-BR": "“\(path)” está sendo usado por outro processo.",
        "pt-PT": "“\(path)” está a ser utilizado por outro processo.",
        "es": "“\(path)” está en uso por otro proceso.",
    ]

    private static let insufficientDiskSpaceExpected: [String: String] = [
        "en": "Not enough disk space to complete the operation.",
        "pt-BR": "Espaço em disco insuficiente para concluir a operação.",
        "pt-PT": "Espaço em disco insuficiente para concluir a operação.",
        "es": "Espacio en disco insuficiente para completar la operación.",
    ]

    private static let volumeDisconnectedExpected: [String: String] = [
        "en": "The volume for “\(path)” was disconnected.",
        "pt-BR": "O volume de “\(path)” foi desconectado.",
        "pt-PT": "O volume de “\(path)” foi desligado.",
        "es": "El volumen de “\(path)” se desconectó.",
    ]

    private static let pathTooLongExpected: [String: String] = [
        "en": "The destination path “\(path)” is too long.",
        "pt-BR": "O caminho de destino “\(path)” é muito longo.",
        "pt-PT": "O caminho de destino “\(path)” é demasiado longo.",
        "es": "La ruta de destino “\(path)” es demasiado larga.",
    ]

    @Test(".permissionDenied exact text per locale", arguments: languages)
    func permissionDenied(language: String) {
        let actual = Self.message("fileSystemError.permissionDenied", language: language, Self.url.path)
        #expect(actual == Self.permissionDeniedExpected[language])
    }

    @Test(".alreadyExists exact text per locale", arguments: languages)
    func alreadyExists(language: String) {
        let actual = Self.message("fileSystemError.alreadyExists", language: language, Self.url.path)
        #expect(actual == Self.alreadyExistsExpected[language])
    }

    @Test(".fileInUse exact text per locale", arguments: languages)
    func fileInUse(language: String) {
        let actual = Self.message("fileSystemError.fileInUse", language: language, Self.url.path)
        #expect(actual == Self.fileInUseExpected[language])
    }

    @Test(".insufficientDiskSpace exact text per locale", arguments: languages)
    func insufficientDiskSpace(language: String) {
        let actual = Self.message("fileSystemError.insufficientDiskSpace", language: language)
        #expect(actual == Self.insufficientDiskSpaceExpected[language])
    }

    @Test(".volumeDisconnected exact text per locale", arguments: languages)
    func volumeDisconnected(language: String) {
        let actual = Self.message("fileSystemError.volumeDisconnected", language: language, Self.url.path)
        #expect(actual == Self.volumeDisconnectedExpected[language])
    }

    @Test(".pathTooLong exact text per locale", arguments: languages)
    func pathTooLong(language: String) {
        let actual = Self.message("fileSystemError.pathTooLong", language: language, Self.url.path)
        #expect(actual == Self.pathTooLongExpected[language])
    }


    @Test("errorDescription wires each case to the correct key and formats the URL argument")
    func errorDescriptionWiring() {
        #expect(FileSystemServiceError.permissionDenied(Self.url).errorDescription == Self.permissionDeniedExpected["en"])
        #expect(FileSystemServiceError.alreadyExists(Self.url).errorDescription == Self.alreadyExistsExpected["en"])
        #expect(FileSystemServiceError.fileInUse(Self.url).errorDescription == Self.fileInUseExpected["en"])
        #expect(FileSystemServiceError.insufficientDiskSpace.errorDescription == Self.insufficientDiskSpaceExpected["en"])
        #expect(FileSystemServiceError.volumeDisconnected(Self.url).errorDescription == Self.volumeDisconnectedExpected["en"])
        #expect(FileSystemServiceError.pathTooLong(Self.url).errorDescription == Self.pathTooLongExpected["en"])
    }
}

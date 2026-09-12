import Foundation
import CoreTransferable
import UniformTypeIdentifiers

struct DraggedFileURLs: Codable, Transferable {
    let sourcePanelID: UUID
    let paths: [URL]

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}

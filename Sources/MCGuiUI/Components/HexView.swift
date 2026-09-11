import SwiftUI

public struct HexRow: Equatable {
    public let offset: String
    public let hex: String
    public let ascii: String
}

public enum HexFormatter {
    public static let bytesPerRow = 16

    public static func formatRow(bytes: [UInt8], offset: Int) -> HexRow {
        let offsetString = String(format: "%08X", offset)
        let hexString = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
        let asciiString = String(bytes.map { byte -> Character in
            (byte >= 0x20 && byte <= 0x7E) ? Character(UnicodeScalar(byte)) : "."
        })
        return HexRow(offset: offsetString, hex: hexString, ascii: asciiString)
    }
}

@MainActor
public struct HexView: View {
    public let data: Data

    public init(data: Data) {
        self.data = data
    }

    private var rowCount: Int {
        data.isEmpty ? 0 : (data.count + HexFormatter.bytesPerRow - 1) / HexFormatter.bytesPerRow
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(0..<rowCount, id: \.self) { rowIndex in
                    let row = HexFormatter.formatRow(
                        bytes: bytesForRow(rowIndex),
                        offset: rowIndex * HexFormatter.bytesPerRow
                    )
                    HStack(alignment: .top, spacing: 12) {
                        Text(row.offset)
                            .foregroundStyle(.secondary)
                        Text(row.hex)
                            .frame(minWidth: 340, alignment: .leading)
                        Text(row.ascii)
                    }
                    .font(.system(.body, design: .monospaced))
                }
            }
        }
    }

    private func bytesForRow(_ rowIndex: Int) -> [UInt8] {
        let start = data.startIndex + rowIndex * HexFormatter.bytesPerRow
        let end = min(start + HexFormatter.bytesPerRow, data.endIndex)
        return Array(data[start..<end])
    }
}

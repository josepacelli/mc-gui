import SwiftUI

/// One formatted row of a hex/ASCII dump: an offset label, space-separated hex byte
/// pairs, and the ASCII rendering of those same bytes.
public struct HexRow: Equatable {
    public let offset: String
    public let hex: String
    public let ascii: String
}

/// Pure byte-chunk -> `HexRow` formatting, kept separate from `HexView` so it's
/// unit-testable without going through SwiftUI (FV-04).
public enum HexFormatter {
    /// Bytes shown per row - the conventional hex-dump width.
    public static let bytesPerRow = 16

    /// Formats `bytes` (a chunk of at most `bytesPerRow` bytes, e.g. a full or partial
    /// row from `HexView`) into an offset/hex/ASCII row. `offset` is the byte offset of
    /// `bytes.first` within the full file, shown as an 8-digit uppercase hex address.
    /// Non-printable bytes (outside the printable ASCII range 0x20-0x7E) render as `.`
    /// in the ASCII column.
    public static func formatRow(bytes: [UInt8], offset: Int) -> HexRow {
        let offsetString = String(format: "%08X", offset)
        let hexString = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
        let asciiString = String(bytes.map { byte -> Character in
            (byte >= 0x20 && byte <= 0x7E) ? Character(UnicodeScalar(byte)) : "."
        })
        return HexRow(offset: offsetString, hex: hexString, ascii: asciiString)
    }
}

/// A virtualized hex/ASCII dump of `data` (FV-04): offset, hex, and ASCII columns, one
/// row per `HexFormatter.bytesPerRow` bytes. Rows are produced lazily by `LazyVStack`
/// inside a `ScrollView` - only visible rows are formatted/rendered, so a 100MB file
/// (FV-07) doesn't allocate every row up front.
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

import Testing
@testable import MCGuiUI

@Suite("HexFormatter - byte chunk to hex/ASCII row (FV-04)")
struct HexFormatterTests {

    // MARK: - standard 16-byte row

    @Test("formatRow on a full 16-byte row formats offset, hex, and ASCII columns")
    func formatRowStandardFullRow() {
        // "Hello, world!" (13 bytes) padded with 3 non-printable bytes to fill the row.
        let bytes: [UInt8] = Array("Hello, world!".utf8) + [0x00, 0x01, 0x02]

        let row = HexFormatter.formatRow(bytes: bytes, offset: 0)

        #expect(row.offset == "00000000")
        #expect(row.hex == "48 65 6C 6C 6F 2C 20 77 6F 72 6C 64 21 00 01 02")
        #expect(row.ascii == "Hello, world!...")
    }

    @Test("formatRow uses the given offset for the offset column, in 8-digit uppercase hex")
    func formatRowUsesGivenOffset() {
        let bytes: [UInt8] = Array(repeating: 0x41, count: 16)

        let row = HexFormatter.formatRow(bytes: bytes, offset: 0x100)

        #expect(row.offset == "00000100")
    }

    // MARK: - partial last row

    @Test("formatRow on a partial (less than 16-byte) row only formats the bytes present")
    func formatRowPartialLastRow() {
        let bytes: [UInt8] = [0x41, 0x42, 0x43]

        let row = HexFormatter.formatRow(bytes: bytes, offset: 16)

        #expect(row.offset == "00000010")
        #expect(row.hex == "41 42 43")
        #expect(row.ascii == "ABC")
    }

    @Test("formatRow on an empty byte chunk produces empty hex/ASCII columns")
    func formatRowEmptyChunk() {
        let row = HexFormatter.formatRow(bytes: [], offset: 0)

        #expect(row.hex == "")
        #expect(row.ascii == "")
    }

    // MARK: - non-printable byte ASCII fallback

    @Test("formatRow renders non-printable bytes as '.' in the ASCII column")
    func formatRowNonPrintableBytesFallBackToDot() {
        // 0x00 (NUL), 0x1F (below printable range), 0x7F (DEL, above printable range),
        // and 0xFF (outside 7-bit ASCII entirely) must all render as '.'.
        let bytes: [UInt8] = [0x00, 0x1F, 0x7F, 0xFF]

        let row = HexFormatter.formatRow(bytes: bytes, offset: 0)

        #expect(row.ascii == "....")
    }

    @Test("formatRow renders the boundary printable bytes (space and tilde) as themselves, not '.'")
    func formatRowPrintableBoundaryBytes() {
        // 0x20 (space) and 0x7E (~) are the inclusive bounds of the printable range.
        let bytes: [UInt8] = [0x20, 0x7E]

        let row = HexFormatter.formatRow(bytes: bytes, offset: 0)

        #expect(row.ascii == " ~")
    }

    // MARK: - row sizing

    @Test("bytesPerRow is 16, the conventional hex-dump row width")
    func bytesPerRowIsSixteen() {
        #expect(HexFormatter.bytesPerRow == 16)
    }
}

import Testing

@testable import INDIMCPKit

@Test func parseINDIIntParsesPlainIntegerStrings() {
    #expect(parseINDIInt("42") == 42)
    #expect(parseINDIInt("-7") == -7)
}

@Test func parseINDIIntParsesFloatFormattedWholeNumbers() {
    // INDI number properties are floats on the wire even for integer pixel/binning/bit-depth
    // values — a driver serializing e.g. "2.0000" for CCD_BINNING's HOR_BIN must still parse.
    #expect(parseINDIInt("2.0000") == 2)
    #expect(parseINDIInt("1600.0") == 1600)
}

@Test func parseINDIIntTruncatesFractionalValues() {
    #expect(parseINDIInt("2.7") == 2)
}

@Test func parseINDIIntReturnsNilForNilOrUnparseableInput() {
    #expect(parseINDIInt(nil) == nil)
    #expect(parseINDIInt("not-a-number") == nil)
    #expect(parseINDIInt("") == nil)
}

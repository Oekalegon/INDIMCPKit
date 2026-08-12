import Foundation
import Testing

@testable import INDIMCPKit

@Test func decodesFocusRangeFromServerJSONShape() throws {
    let range = try JSONDecoder().decode(FocusRange.self, from: Data("[10.0, 500.0]".utf8))
    #expect(range == FocusRange(min: 10, max: 500))
}

@Test func encodesFocusRangeAsTwoElementArray() throws {
    let data = try JSONEncoder().encode(FocusRange(min: 10, max: 500))
    #expect(String(data: data, encoding: .utf8) == "[10,500]")
}

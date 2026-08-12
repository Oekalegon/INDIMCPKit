import Foundation
import Testing

@testable import INDIMCPKit

@Test func decodesKnownPropertyStateValues() throws {
    #expect(try decode("\"Idle\"") == .idle)
    #expect(try decode("\"Ok\"") == .ok)
    #expect(try decode("\"Busy\"") == .busy)
    #expect(try decode("\"Alert\"") == .alert)
}

@Test func decodesUnknownPropertyStateAsOther() throws {
    #expect(try decode("\"SomethingElse\"") == .other("SomethingElse"))
}

@Test func roundTripsThroughEncoding() throws {
    let data = try JSONEncoder().encode(PropertyState.other("Weird"))
    #expect(String(data: data, encoding: .utf8) == "\"Weird\"")
}

private func decode(_ json: String) throws -> PropertyState {
    try JSONDecoder().decode(PropertyState.self, from: Data(json.utf8))
}

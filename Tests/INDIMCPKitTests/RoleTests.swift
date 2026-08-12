import Foundation
import Testing

@testable import INDIMCPKit

@Test func decodesKnownRoleValues() throws {
    #expect(try decode("\"camera\"") == .camera)
    #expect(try decode("\"filterWheel\"") == .filterWheel)
    #expect(try decode("\"mount\"") == .mount)
}

@Test func decodesUnrecognizedRoleAsRawValue() throws {
    #expect(try decode("\"dovetailBar\"") == Role(rawValue: "dovetailBar"))
}

@Test func decodesComponentWithUnrecognizedRole() throws {
    let json = Data(#"{"role": "dovetailBar", "id": "d1"}"#.utf8)
    let component = try JSONDecoder().decode(Component.self, from: json)
    #expect(component.role == Role(rawValue: "dovetailBar"))
}

@Test func roleRoundTripsThroughEncoding() throws {
    let data = try JSONEncoder().encode(Role(rawValue: "dovetailBar"))
    #expect(String(data: data, encoding: .utf8) == "\"dovetailBar\"")
}

private func decode(_ json: String) throws -> Role {
    try JSONDecoder().decode(Role.self, from: Data(json.utf8))
}

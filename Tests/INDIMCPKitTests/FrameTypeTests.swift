import Foundation
import Testing

@testable import INDIMCPKit

@Test func decodesKnownFrameTypeValues() throws {
    #expect(try JSONDecoder().decode(FrameType.self, from: Data(#""Light""#.utf8)) == .light)
    #expect(try JSONDecoder().decode(FrameType.self, from: Data(#""Dark""#.utf8)) == .dark)
    #expect(try JSONDecoder().decode(FrameType.self, from: Data(#""Flat""#.utf8)) == .flat)
    #expect(try JSONDecoder().decode(FrameType.self, from: Data(#""Bias""#.utf8)) == .bias)
}

@Test func unrecognizedFrameTypeFailsToDecode() {
    #expect(throws: (any Error).self) {
        try JSONDecoder().decode(FrameType.self, from: Data(#""SomethingElse""#.utf8))
    }
}

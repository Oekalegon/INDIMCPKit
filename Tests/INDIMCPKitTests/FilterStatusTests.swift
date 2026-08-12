import Foundation
import Testing

@testable import INDIMCPKit

@Test func decodesKnownFilterSyncStatusValues() throws {
    #expect(try JSONDecoder().decode(FilterSyncStatus.self, from: Data(#""matched""#.utf8)) == .matched)
    #expect(try JSONDecoder().decode(FilterSyncStatus.self, from: Data(#""synced""#.utf8)) == .synced)
}

@Test func decodesKnownFilterAdoptStatusValues() throws {
    #expect(try JSONDecoder().decode(FilterAdoptStatus.self, from: Data(#""matched""#.utf8)) == .matched)
    #expect(try JSONDecoder().decode(FilterAdoptStatus.self, from: Data(#""adopted""#.utf8)) == .adopted)
}

@Test func unrecognizedFilterSyncStatusFailsToDecode() {
    // Unlike PropertyState/Role, these are closed sets on the server side too (a Literal, not a
    // Literal | str union) — an unrecognized value should be a decode error, not a silent
    // fallback, since it would mean this kit is talking to a server version it doesn't
    // understand.
    #expect(throws: (any Error).self) {
        try JSONDecoder().decode(FilterSyncStatus.self, from: Data(#""somethingElse""#.utf8))
    }
}

import Foundation
import Testing

@testable import INDIMCPKit

@Test func decodesServerInfoWithBuildTimestamp() throws {
    let json = Data(#"{"version": "1.2.3", "buildTimestamp": "2026-08-13T10:00:00Z"}"#.utf8)
    let info = try JSONDecoder().decode(ServerInfo.self, from: json)
    #expect(info == ServerInfo(version: "1.2.3", buildTimestamp: "2026-08-13T10:00:00Z"))
}

@Test func decodesServerInfoWithNullBuildTimestamp() throws {
    let json = Data(#"{"version": "1.2.3", "buildTimestamp": null}"#.utf8)
    let info = try JSONDecoder().decode(ServerInfo.self, from: json)
    #expect(info.buildTimestamp == nil)
}

@Test func matchesAlignedVersionReflectsExactEquality() {
    #expect(ServerInfo(version: alignedINDIMCPServerVersion, buildTimestamp: nil).matchesAlignedVersion)
    #expect(!ServerInfo(version: "999.0.0", buildTimestamp: nil).matchesAlignedVersion)
}

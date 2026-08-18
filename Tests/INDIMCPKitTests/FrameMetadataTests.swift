import Foundation
import Testing

@testable import INDIMCPKit

@Test func decodesFrameMetadataFromServerJSONShape() throws {
    let json = Data(
        #"""
        {"frameId": "f1", "runId": "r1", "device": "CCD Simulator", "sizeBytes": 1048576,
         "checksumSha256": "abc123", "capturedAt": "2026-01-01T00:00:00+00:00", "transferredAt": null}
        """#.utf8
    )
    let metadata = try JSONDecoder().decode(FrameMetadata.self, from: json)
    #expect(metadata.frameId == "f1")
    #expect(metadata.runId == "r1")
    #expect(metadata.device == "CCD Simulator")
    #expect(metadata.sizeBytes == 1_048_576)
    #expect(metadata.checksumSha256 == "abc123")
    #expect(metadata.transferredAt == nil)
}

@Test func decodesFrameMetadataWithNoRunId() throws {
    let json = Data(
        #"""
        {"frameId": "f1", "runId": null, "device": "CCD Simulator", "sizeBytes": 1048576,
         "checksumSha256": "abc123", "capturedAt": "2026-01-01T00:00:00+00:00",
         "transferredAt": "2026-01-01T00:05:00+00:00"}
        """#.utf8
    )
    let metadata = try JSONDecoder().decode(FrameMetadata.self, from: json)
    #expect(metadata.runId == nil)
    #expect(metadata.transferredAt == "2026-01-01T00:05:00+00:00")
}

@Test func decodesFrameMetadataWithNoChecksum() throws {
    // A frame captured before checksum support existed (INDIMCP-95) reports
    // checksumSha256: null — its row predates the column and was carried forward by a schema
    // migration with nothing left to hash.
    let json = Data(
        #"""
        {"frameId": "f1", "runId": null, "device": "CCD Simulator", "sizeBytes": 1048576,
         "checksumSha256": null, "capturedAt": "2026-01-01T00:00:00+00:00", "transferredAt": null}
        """#.utf8
    )
    let metadata = try JSONDecoder().decode(FrameMetadata.self, from: json)
    #expect(metadata.checksumSha256 == nil)
}

@Test func decodesFrameMetadataResponseWithDownloadUrl() throws {
    let json = Data(
        #"""
        {"frameId": "f1", "runId": "r1", "device": "CCD Simulator", "sizeBytes": 1048576,
         "checksumSha256": "abc123", "capturedAt": "2026-01-01T00:00:00+00:00", "transferredAt": null,
         "downloadUrl": "http://telescope.local:8000/frames/f1", "issues": []}
        """#.utf8
    )
    let response = try JSONDecoder().decode(FrameMetadataResponse.self, from: json)
    #expect(response.downloadUrl == "http://telescope.local:8000/frames/f1")
    #expect(response.checksumSha256 == "abc123")
    #expect(response.issues.isEmpty)
}

@Test func decodesFrameMetadataResponseWithNoDownloadUrl() throws {
    // The server returns downloadUrl: null when it has no HTTP listener to build one from
    // (running under the stdio transport) — downloadFrame is expected to throw
    // frameNotDownloadable rather than crash on this.
    let json = Data(
        #"""
        {"frameId": "f1", "runId": null, "device": "CCD Simulator", "sizeBytes": 1048576,
         "checksumSha256": "abc123", "capturedAt": "2026-01-01T00:00:00+00:00", "transferredAt": null,
         "downloadUrl": null, "issues": []}
        """#.utf8
    )
    let response = try JSONDecoder().decode(FrameMetadataResponse.self, from: json)
    #expect(response.downloadUrl == nil)
}

@Test func decodesFrameMetadataResponseWithFrameChecksumMissingIssue() throws {
    // A legacy frame (checksumSha256: null) carries a matching frameChecksumMissing WARNING
    // Issue explaining why (INDIMCP-107) — a client shouldn't have to infer the reason for a
    // null checksum on its own.
    let json = Data(
        #"""
        {"frameId": "f1", "runId": null, "device": "CCD Simulator", "sizeBytes": 1048576,
         "checksumSha256": null, "capturedAt": "2026-01-01T00:00:00+00:00", "transferredAt": null,
         "downloadUrl": null,
         "issues": [{"kind": "issue", "severity": "Warning", "code": "frameChecksumMissing",
                      "message": "frame 'f1' has no checksumSha256",
                      "role": null, "device": "CCD Simulator"}]}
        """#.utf8
    )
    let response = try JSONDecoder().decode(FrameMetadataResponse.self, from: json)
    #expect(response.issues.count == 1)
    #expect(response.issues[0].code == "frameChecksumMissing")
    #expect(response.issues[0].severity == .warning)
    #expect(response.issues[0].device == "CCD Simulator")
}

@Test func decodesFrameMetadataResponseWithNoIssuesKeyAtAll() throws {
    // A server instance that hasn't been redeployed past INDIMCP-107 yet sends a response with
    // no "issues" key at all, not an empty array — this must default to [] rather than throwing
    // keyNotFound, the same tolerance checksumSha256 already has for a server predating
    // INDIMCP-95 (see FrameMetadataResponse.init(from:)'s own doc comment for why).
    let json = Data(
        #"""
        {"frameId": "f1", "runId": null, "device": "CCD Simulator", "sizeBytes": 1048576,
         "checksumSha256": "abc123", "capturedAt": "2026-01-01T00:00:00+00:00", "transferredAt": null,
         "downloadUrl": null}
        """#.utf8
    )
    let response = try JSONDecoder().decode(FrameMetadataResponse.self, from: json)
    #expect(response.issues.isEmpty)
}

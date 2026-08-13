import Foundation
import Testing

@testable import INDIMCPKit

@Test func decodesFrameMetadataFromServerJSONShape() throws {
    let json = Data(
        #"""
        {"frameId": "f1", "runId": "r1", "device": "CCD Simulator", "sizeBytes": 1048576,
         "capturedAt": "2026-01-01T00:00:00+00:00", "transferredAt": null}
        """#.utf8
    )
    let metadata = try JSONDecoder().decode(FrameMetadata.self, from: json)
    #expect(metadata.frameId == "f1")
    #expect(metadata.runId == "r1")
    #expect(metadata.device == "CCD Simulator")
    #expect(metadata.sizeBytes == 1_048_576)
    #expect(metadata.transferredAt == nil)
}

@Test func decodesFrameMetadataWithNoRunId() throws {
    let json = Data(
        #"""
        {"frameId": "f1", "runId": null, "device": "CCD Simulator", "sizeBytes": 1048576,
         "capturedAt": "2026-01-01T00:00:00+00:00", "transferredAt": "2026-01-01T00:05:00+00:00"}
        """#.utf8
    )
    let metadata = try JSONDecoder().decode(FrameMetadata.self, from: json)
    #expect(metadata.runId == nil)
    #expect(metadata.transferredAt == "2026-01-01T00:05:00+00:00")
}

@Test func decodesFrameMetadataResponseWithDownloadUrl() throws {
    let json = Data(
        #"""
        {"frameId": "f1", "runId": "r1", "device": "CCD Simulator", "sizeBytes": 1048576,
         "capturedAt": "2026-01-01T00:00:00+00:00", "transferredAt": null,
         "downloadUrl": "http://telescope.local:8000/frames/f1"}
        """#.utf8
    )
    let response = try JSONDecoder().decode(FrameMetadataResponse.self, from: json)
    #expect(response.downloadUrl == "http://telescope.local:8000/frames/f1")
}

@Test func decodesFrameMetadataResponseWithNoDownloadUrl() throws {
    // The server returns downloadUrl: null when it has no HTTP listener to build one from
    // (running under the stdio transport) — downloadFrame is expected to throw
    // frameNotDownloadable rather than crash on this.
    let json = Data(
        #"""
        {"frameId": "f1", "runId": null, "device": "CCD Simulator", "sizeBytes": 1048576,
         "capturedAt": "2026-01-01T00:00:00+00:00", "transferredAt": null, "downloadUrl": null}
        """#.utf8
    )
    let response = try JSONDecoder().decode(FrameMetadataResponse.self, from: json)
    #expect(response.downloadUrl == nil)
}

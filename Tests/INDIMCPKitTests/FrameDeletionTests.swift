import Foundation
import Testing

@testable import INDIMCPKit

/// Pure, offline tests for the frame-download/deletion guard clauses — everything here throws
/// (or doesn't) before ever touching the network, so none of it needs a live server.

@Test func downloadFrameThrowsWhenNoDownloadUrl() async throws {
    let client = INDIMCPClient(endpoint: try #require(URL(string: "http://127.0.0.1:1")))
    let frame = FrameMetadataResponse(
        frameId: "f1", runId: nil, device: "CCD Simulator", sizeBytes: 1024,
        capturedAt: "2026-01-01T00:00:00+00:00", transferredAt: nil, downloadUrl: nil
    )
    let destination = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)

    await #expect(throws: INDIMCPClientError.self) {
        try await client.downloadFrame(frame, to: destination)
    }
}

@Test func deleteAllFramesRefusesWithoutAcknowledgment() async throws {
    // No real server reachable at this endpoint — if this reached the network at all (i.e. the
    // acknowledgment guard didn't fire first), it would fail with a connection error instead of
    // allFramesDeletionNotAcknowledged, so this also proves the guard runs before any tool call.
    let client = INDIMCPClient(endpoint: try #require(URL(string: "http://127.0.0.1:1")))

    await #expect(throws: INDIMCPClientError.self) {
        _ = try await client.deleteAllFrames(acknowledgingPermanentDataLoss: false)
    }
}

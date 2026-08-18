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

@Test func downloadAllFramesCreatesNoDirectoryWhenListFramesFails() async throws {
    // No real server reachable at this endpoint, so listFrames(runId:) fails before
    // downloadAllFrames ever gets to creating a directory or downloading anything — proves the
    // directory-creation side effect only happens once listFrames has actually succeeded.
    let client = INDIMCPClient(endpoint: try #require(URL(string: "http://127.0.0.1:1")))
    let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)

    await #expect(throws: (any Error).self) {
        _ = try await client.downloadAllFrames(runId: "run-1", to: directory)
    }

    #expect(!FileManager.default.fileExists(atPath: directory.path))
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

@Test func reachableURLSubstitutesTheEndpointsHost() throws {
    // INDIMCP-server computes downloadUrl from its own socket.gethostname() (an mDNS .local
    // name), which isn't reliably resolvable from every client's network even though the same
    // server is already reachable at whatever host the client used to connect via MCP.
    let client = INDIMCPClient(endpoint: try #require(URL(string: "http://192.168.1.50:8000/mcp")))
    let downloadUrl = try #require(URL(string: "http://telescope.local:8000/frames/abc123"))

    let reachable = client.reachableURL(for: downloadUrl)

    #expect(reachable.host == "192.168.1.50")
    #expect(reachable.port == 8000)
    #expect(reachable.path == "/frames/abc123")
    #expect(reachable.scheme == "http")
}

@Test func reachableURLLeavesAMatchingHostAlone() throws {
    let client = INDIMCPClient(endpoint: try #require(URL(string: "http://192.168.1.50:8000/mcp")))
    let downloadUrl = try #require(URL(string: "http://192.168.1.50:8000/frames/abc123"))

    #expect(client.reachableURL(for: downloadUrl) == downloadUrl)
}

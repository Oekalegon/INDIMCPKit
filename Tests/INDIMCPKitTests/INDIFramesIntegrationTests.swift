import Foundation
import Testing

@testable import INDIMCPKit

/// Exercises `listFrames`/`getFrameMetadata`/`purgeTransferredFrames` against a real, running
/// INDIMCP-server.
///
/// This dev environment has no real INDI driver catalog (see `DeviceAbstractionsIntegrationTests`'
/// doc comment) — `capture_frame` never actually produces a frame here, only starts a run that
/// fails quickly for lack of a connected camera. So unlike `INDIScriptRunsIntegrationTests`, this
/// suite can't exercise the full "capture a real frame, then download it" path; it's scoped to
/// what's verifiable without one: request/response shape round-tripping against the real server
/// (proving the snake_case argument names and `structuredContent` decode actually match), and the
/// not-found error path. `downloadFrame`'s HTTP path itself is covered by
/// `downloadFrameThrowsWhenNoDownloadUrl` (a pure unit test) and by manual verification against a
/// server with a real driver attached — see this suite's own limitation rather than a gap to fill
/// here.
///
/// **Known gap, not covered here at all:** `deleteAllTransferredFrames`/`deleteAllFrames`'s actual
/// deletion behavior. `FrameDeletionTests.swift` only covers their pre-network guard clauses
/// (`deleteAllFrames` refusing without `acknowledgingPermanentDataLoss: true`) — the deletion
/// logic itself was verified manually against a real server by inserting frames directly via
/// `frame_store.save_frame` (one pre-confirmed transferred, one not) and confirming
/// `deleteAllTransferredFrames` removed only the transferred one while `deleteAllFrames(true)`
/// removed what remained, but that verification wasn't captured as a repeatable test — this
/// codebase's tests only ever drive the server through its actual MCP tools, never by reaching
/// around it into `frame_store` directly the way that manual check did. Promote this into a real
/// test here once a real frame is producible some other way (e.g. once a driver like the CCD
/// Simulator can actually be connected through and `capture_frame` produces one for real).
@Suite("INDI frames (live server)")
struct INDIFramesIntegrationTests {
    @Test(
        "listFrames round-trips against the real server with no filters",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func listFramesRoundTrips() async throws {
        let client = try await connectedTestClient()
        _ = try await client.listFrames()
        await client.disconnect()
    }

    @Test(
        "listFrames round-trips with every filter set",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func listFramesRoundTripsWithFilters() async throws {
        let client = try await connectedTestClient()
        _ = try await client.listFrames(
            runId: "nonexistent-run", device: "CCD Simulator", since: "2026-01-01T00:00:00+00:00",
            transferred: false
        )
        await client.disconnect()
    }

    @Test(
        "getFrameMetadata throws for an unknown frameId",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func getFrameMetadataThrowsForUnknownFrame() async throws {
        let client = try await connectedTestClient()

        await #expect(throws: INDIMCPClientError.self) {
            _ = try await client.getFrameMetadata(frameId: "indimcpkit-test-\(UUID().uuidString)")
        }

        await client.disconnect()
    }

    @Test(
        "purgeTransferredFrames round-trips against the real server",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func purgeTransferredFramesRoundTrips() async throws {
        let client = try await connectedTestClient()
        // A very large window so this never actually deletes anything real in a shared test
        // server — this is checking the call shape round-trips, not exercising deletion.
        _ = try await client.purgeTransferredFrames(olderThanDays: 3650)
        await client.disconnect()
    }

    // Like `listFrames`/`purgeTransferredFrames` above, this dev environment can't produce a real
    // frame (see this suite's doc comment), so this only covers the empty-run path: the
    // `listFrames(runId:)` call round-trips and, since there's nothing to download, `directory`
    // still gets created. Actually downloading a frame this way is covered by manual verification
    // the same way `downloadFrame` itself is, until a real driver can produce one.
    @Test(
        "downloadAllFrames creates the directory and downloads nothing for a run with no frames",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func downloadAllFramesRoundTripsForEmptyRun() async throws {
        let client = try await connectedTestClient()
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)

        let downloaded = try await client.downloadAllFrames(runId: "nonexistent-run", to: directory)

        #expect(downloaded.isEmpty)
        #expect(FileManager.default.fileExists(atPath: directory.path))
        await client.disconnect()
    }
}

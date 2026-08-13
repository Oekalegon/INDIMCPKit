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
}

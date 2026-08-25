import Foundation
import Testing

@testable import INDIMCPKit

/// Exercises `listFrames`/`getFrameMetadata`/`purgeTransferredFrames` against a real, running
/// INDIMCP-server.
///
/// Most of this suite predates a working local INDI driver catalog and is still scoped to what's
/// verifiable without a real captured frame: request/response shape round-tripping against the
/// real server (proving the snake_case argument names and `structuredContent` decode actually
/// match), and the not-found error path. `downloadFrame`'s HTTP path itself is covered by
/// `downloadFrameThrowsWhenNoDownloadUrl` (a pure unit test).
///
/// `frameLifecycleConfirmTransferThenDelete` below is the exception — it drives a real CCD
/// Simulator capture (see that test's own doc comment for setup requirements) and exercises
/// `getFrameMetadata`/`confirmFrameTransfer`/`deleteFrame`'s success paths against an actual
/// captured frame (IMCPKIT-63, previously blocked on INDIMCP-128's hardcoded `/usr/share/indi/`
/// catalog path).
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
/// test here following the same driver-connect-and-capture pattern as
/// `frameLifecycleConfirmTransferThenDelete`.
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

    /// Exercises `getFrameMetadata`/`confirmFrameTransfer`/`deleteFrame`'s success paths against a
    /// real captured frame (IMCPKIT-63).
    ///
    /// Needs an actual connected camera: starts the CCD Simulator driver, connects it, and runs a
    /// real `capture_frame`. Requires `INDI_MCP_DRIVER_CATALOG_DIR` to point at a populated INDI
    /// driver catalog when the INDIMCP-server process itself is launched (e.g.
    /// `/usr/local/share/indi` on this machine via Homebrew) — see `INDIDriverManagementIntegrationTests`
    /// for how the driver catalog path is configured (INDIMCP-128). Uses `IndiServerTestLock` like
    /// `INDIScriptRunsIntegrationTests` since it starts/stops the shared `indiserver` process and a
    /// driver.
    @Test(
        "getFrameMetadata/confirmFrameTransfer/deleteFrame round-trip a real captured frame",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func frameLifecycleConfirmTransferThenDelete() async throws {
        try await IndiServerTestLock.withLock {
            let client = try await connectedTestClient()
            _ = try await client.startINDIServer()
            _ = try await client.startINDIMessaging()
            _ = try await client.startINDIDriver(label: "CCD Simulator")

            let rig = Rig(
                id: "indimcpkit-test-\(UUID().uuidString)",
                name: "Frame Lifecycle Test Rig",
                components: [Component(role: .camera, id: "cam1", device: "CCD Simulator")]
            )
            _ = try await client.saveRig(rig)

            let connectStarted = try await client.connectDevice(rigId: rig.id, role: "camera")
            _ = try await client.waitForTerminalStatus(
                runId: connectStarted.runId, pollInterval: .milliseconds(200), maxAttempts: 50
            )

            let captureStarted = try await client.captureFrame(rigId: rig.id, exposureSeconds: 1)
            let captureStatus = try await client.waitForTerminalStatus(
                runId: captureStarted.runId, pollInterval: .milliseconds(200), maxAttempts: 100
            )
            guard case .completed(let completed) = captureStatus else {
                Testing.Issue.record("expected capture_frame to complete, got \(captureStatus)")
                _ = try await client.disconnectDevice(rigId: rig.id, role: "camera")
                _ = try await client.stopINDIDriver(label: "CCD Simulator")
                await client.disconnect()
                return
            }

            let captured = try await client.listFrames(runId: completed.runId)
            let frameId = try #require(captured.first?.frameId)

            // getFrameMetadata's success path — a real frame_id, not just the unknown-id error case.
            let metadata = try await client.getFrameMetadata(frameId: frameId)
            #expect(metadata.frameId == frameId)
            #expect(metadata.transferredAt == nil)

            // deleteFrame refuses an unconfirmed frame by default.
            await #expect(throws: INDIMCPClientError.self) {
                _ = try await client.deleteFrame(frameId: frameId)
            }

            let confirmed = try await client.confirmFrameTransfer(frameId: frameId)
            #expect(confirmed.frameId == frameId)
            #expect(confirmed.transferredAt != nil)

            let deleted = try await client.deleteFrame(frameId: frameId)
            #expect(deleted.frameId == frameId)
            #expect(deleted.transferredAt != nil)

            await #expect(throws: INDIMCPClientError.self) {
                _ = try await client.getFrameMetadata(frameId: frameId)
            }

            // deleteFrame(requireTransferred: false) overrides the guard above, deleting a second
            // frame that was never confirmed transferred.
            let secondCaptureStarted = try await client.captureFrame(rigId: rig.id, exposureSeconds: 1)
            let secondCaptureStatus = try await client.waitForTerminalStatus(
                runId: secondCaptureStarted.runId, pollInterval: .milliseconds(200), maxAttempts: 100
            )
            if case .completed(let secondCompleted) = secondCaptureStatus {
                let secondCaptured = try await client.listFrames(runId: secondCompleted.runId)
                let secondFrameId = try #require(secondCaptured.first?.frameId)

                let secondDeleted = try await client.deleteFrame(
                    frameId: secondFrameId, requireTransferred: false
                )
                #expect(secondDeleted.frameId == secondFrameId)
                #expect(secondDeleted.transferredAt == nil)
            } else {
                Testing.Issue.record("expected second capture_frame to complete, got \(secondCaptureStatus)")
            }

            _ = try await client.disconnectDevice(rigId: rig.id, role: "camera")
            _ = try await client.stopINDIDriver(label: "CCD Simulator")
            _ = try await client.stopINDIServer()
            await client.disconnect()
        }
    }
}

import Foundation
import Testing

@testable import INDIMCPKit

/// Exercises `INDISensorCalibrationSweep` against a real, running INDIMCP-server with a real
/// `indiserver` process behind it.
///
/// Skipped unless `INDIMCP_TEST_SERVER_URL` is set — see `INDIServerManagementIntegrationTests`
/// for how to run this manually. Same limitation as `INDIScriptRunsIntegrationTests`: there's no
/// connected camera driver in this dev environment, so the sweep's single combination fails
/// almost immediately rather than ever actually capturing a frame — that failure path, and the
/// plumbing around it (start → poll → terminal status, cancel on an already-terminal sweep), is
/// what's actually being verified here. Passes non-default `binningX`/`binningY`/sub-frame values
/// (IMCPKIT-65) rather than leaving them at their 1×1/omitted defaults, so a successful `started`
/// result also confirms the server's `run_calibration_sweep` tool actually accepts those
/// parameter names rather than rejecting them with `ValueError`.
@Suite("INDI sensor calibration sweep (live server)")
struct INDISensorCalibrationSweepIntegrationTests {
    @Test(
        "run a single-combination sweep against a rig with no connected camera; status settles to failed",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func sweepFailsWithoutConnectedDevice() async throws {
        try await IndiServerTestLock.withLock {
            let client = try await connectedTestClient()
            _ = try await client.startINDIServer()
            _ = try await client.startINDIMessaging()

            let rig = Rig(
                id: "indimcpkit-test-\(UUID().uuidString)",
                name: "Sensor Calibration Sweep Test Rig",
                components: [Component(role: .camera, id: "cam1", device: "Not Connected Camera")]
            )
            _ = try await client.saveRig(rig)

            let started = try await client.runSensorCalibrationSweep(
                rigId: rig.id,
                gains: [1.0],
                offsets: [10.0],
                flatExposureSecondsList: [2.5],
                biasCount: 3,
                darkCount: 3,
                binningX: 2,
                binningY: 2,
                frameX: 100,
                frameY: 100,
                frameWidth: 500,
                frameHeight: 500
            )
            #expect(started.rigId == rig.id)
            #expect(started.totalCombinations == 1)

            // The sweep's one combination fails almost immediately (the camera isn't connected),
            // but is asynchronous server-side — poll briefly rather than assuming it's already
            // terminal.
            let status = try await client.waitForTerminalSweepStatus(
                sweepId: started.sweepId,
                pollInterval: .milliseconds(100),
                maxAttempts: 50
            )
            guard case .failed(let failed) = status else {
                Testing.Issue.record("expected a .failed status, got \(status)")
                return
            }
            #expect(failed.sweepId == started.sweepId)
            #expect(failed.rigId == rig.id)
            #expect(failed.failedAtCombination == 0)

            // cancelSensorCalibrationSweep on an already-terminal sweep doesn't error — it just
            // returns the terminal status as-is (mirrors cancelScript's own documented behavior).
            let cancelled = try await client.cancelSensorCalibrationSweep(sweepId: started.sweepId)
            guard case .failed = cancelled else {
                Testing.Issue.record(
                    "expected cancelSensorCalibrationSweep on a terminal sweep to return .failed, got \(cancelled)"
                )
                return
            }

            _ = try await client.stopINDIServer()
            await client.disconnect()
        }
    }
}

import Foundation
import Testing

@testable import INDIMCPKit

/// Exercises `INDIFlatCalibrationSweep` against a real, running INDIMCP-server with a real
/// `indiserver` process behind it.
///
/// Skipped unless `INDIMCP_TEST_SERVER_URL` is set — see `INDIServerManagementIntegrationTests`
/// for how to run this manually. Same limitation as `INDISensorCalibrationSweepIntegrationTests`:
/// there's no connected camera/filter wheel/focuser driver in this dev environment, so the
/// sweep's single combination fails almost immediately rather than ever actually capturing a
/// frame — that failure path, and the plumbing around it (start → poll → terminal status, cancel
/// on an already-terminal sweep), is what's actually being verified here.
@Suite("INDI flat calibration sweep (live server)")
struct INDIFlatCalibrationSweepIntegrationTests {
    @Test(
        "run a single-combination sweep against a rig with no connected devices; status settles to failed",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func sweepFailsWithoutConnectedDevices() async throws {
        try await IndiServerTestLock.withLock {
            let client = try await connectedTestClient()
            _ = try await client.startINDIServer()
            _ = try await client.startINDIMessaging()

            let rig = Rig(
                id: "indimcpkit-test-\(UUID().uuidString)",
                name: "Flat Calibration Sweep Test Rig",
                components: [
                    Component(role: .camera, id: "cam1", device: "Not Connected Camera"),
                    Component(role: .filterWheel, id: "fw1", device: "Not Connected Filter Wheel"),
                    Component(role: .focuser, id: "foc1", device: "Not Connected Focuser"),
                ]
            )
            _ = try await client.saveRig(rig)

            let started = try await client.runFlatCalibrationSweep(
                rigId: rig.id,
                gains: [1.0],
                offsets: [10.0],
                exposureSecondsList: [2.5],
                filterName: "Luminance",
                focusPosition: 5000,
                count: 3
            )
            #expect(started.rigId == rig.id)
            #expect(started.totalCombinations == 1)

            // The sweep's one combination fails almost immediately (nothing is connected), but is
            // asynchronous server-side — poll briefly rather than assuming it's already terminal.
            let status = try await client.waitForTerminalFlatSweepStatus(
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

            // cancelFlatCalibrationSweep on an already-terminal sweep doesn't error — it just
            // returns the terminal status as-is (mirrors cancelSensorCalibrationSweep's own
            // documented behavior).
            let cancelled = try await client.cancelFlatCalibrationSweep(sweepId: started.sweepId)
            guard case .failed = cancelled else {
                Testing.Issue.record(
                    "expected cancelFlatCalibrationSweep on a terminal sweep to return .failed, got \(cancelled)"
                )
                return
            }

            _ = try await client.stopINDIServer()
            await client.disconnect()
        }
    }
}

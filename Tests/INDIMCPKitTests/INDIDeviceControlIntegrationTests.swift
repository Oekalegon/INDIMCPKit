import Foundation
import Testing

@testable import INDIMCPKit

/// Exercises every `INDIMCPClient` device-control convenience wrapper against a real, running
/// INDIMCP-server with a real `indiserver` process behind it.
///
/// Skipped unless `INDIMCP_TEST_SERVER_URL` is set — see `INDIServerManagementIntegrationTests`
/// for how to run this manually. Run the server from the actual INDIMCP-server checkout (like
/// `INDIScriptsIntegrationTests`), since each of these tools starts a real built-in script (park,
/// slew, cool_camera, ...) that must actually be loaded for the call to succeed at all — an
/// unloaded script fails immediately with a different error than the one this suite cares about.
///
/// None of these devices are actually connected in this dev environment, so no run here ever
/// really parks a mount or captures a frame — what's being verified is that each wrapper calls
/// the right underlying tool with the right arguments: `runScript(scriptId:rigId:)` reports back
/// the correct `script` id and the `rigId` this suite passed in has round-tripped correctly, for
/// every one of these fourteen thin wrappers. A wrong tool name (e.g. a typo routing `unpark` to
/// the `"park"` script) would be caught here even though neither actually reaches real hardware.
@Suite("INDI device control (live server)")
struct INDIDeviceControlIntegrationTests {
    @Test(
        "every device-control wrapper starts the correctly named script against the given rig",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func everyWrapperStartsItsScript() async throws {
        let client = try await connectedTestClient()

        let rig = Rig(
            id: "indimcpkit-test-\(UUID().uuidString)",
            name: "Device Control Test Rig",
            components: [
                Component(role: .mount, id: "mnt1", device: "Not Connected Mount"),
                Component(role: .camera, id: "cam1", device: "Not Connected Camera"),
                Component(role: .filterWheel, id: "fw1", device: "Not Connected FW", slots: [1: "Ha"]),
                Component(role: .focuser, id: "foc1", device: "Not Connected Focuser"),
            ]
        )
        _ = try await client.saveRig(rig)

        func assertStarted(_ script: String, _ started: ScriptRunStarted) {
            #expect(started.script == script)
            #expect(started.rigId == rig.id)
        }

        assertStarted("park", try await client.park(rigId: rig.id))
        assertStarted("unpark", try await client.unpark(rigId: rig.id))
        assertStarted("slew", try await client.slew(rigId: rig.id, ra: 5.5, dec: 20))
        assertStarted("track_off", try await client.trackOff(rigId: rig.id))
        assertStarted(
            "set_track_mode",
            try await client.setTrackMode(rigId: rig.id, modeSwitchElement: "TRACK_SIDEREAL")
        )
        assertStarted(
            "set_custom_tracking_rate",
            try await client.setCustomTrackingRate(rigId: rig.id, raRateArcsecPerSec: 1, decRateArcsecPerSec: 0)
        )

        assertStarted("cool_camera", try await client.coolCamera(rigId: rig.id))
        assertStarted("cooler_on", try await client.coolerOn(rigId: rig.id))
        assertStarted("cooler_off", try await client.coolerOff(rigId: rig.id))
        assertStarted("capture_frame", try await client.captureFrame(rigId: rig.id, exposureSeconds: 1))

        assertStarted("select_filter", try await client.selectFilter(rigId: rig.id, filterName: "Ha"))

        assertStarted("set_focus_position", try await client.setFocusPosition(rigId: rig.id, position: 1000))

        assertStarted("connect", try await client.connectDevice(rigId: rig.id, role: "mount"))
        assertStarted("disconnect", try await client.disconnectDevice(rigId: rig.id, role: "mount"))

        await client.disconnect()
    }
}

import Foundation
import Testing

@testable import INDIMCPKit

/// Exercises the composed capture-sequence wrappers against a real, running INDIMCP-server.
///
/// Skipped unless `INDIMCP_TEST_SERVER_URL` is set — see `INDIServerManagementIntegrationTests`
/// for how to run this manually. Run the server from the actual INDIMCP-server checkout (like
/// `INDIDeviceControlIntegrationTests`), since these built-in scripts must be loaded. None of
/// these devices are actually connected, so no run here captures a real frame — see
/// `INDIDeviceControlIntegrationTests`'s doc comment for the same reasoning and the same
/// argument-key-vs-declared-parameters limitation this suite works around the same way.
@Suite("INDI capture sequences (live server)")
struct INDICaptureSequencesIntegrationTests {
    @Test(
        "every capture-sequence wrapper starts the correctly named script against the given rig",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func everyWrapperStartsItsScript() async throws {
        let client = try await connectedTestClient()

        let rig = Rig(
            id: "indimcpkit-test-\(UUID().uuidString)",
            name: "Capture Sequence Test Rig",
            components: [
                Component(role: .mount, id: "mnt1", device: "Not Connected Mount"),
                Component(role: .camera, id: "cam1", device: "Not Connected Camera"),
                Component(role: .filterWheel, id: "fw1", device: "Not Connected FW", slots: [1: "Ha"]),
                Component(role: .focuser, id: "foc1", device: "Not Connected Focuser"),
            ]
        )
        _ = try await client.saveRig(rig)

        let dark = try await client.captureDarkSequence(rigId: rig.id, exposureSeconds: 60, count: 5)
        #expect(dark.script == "capture_dark_sequence")
        #expect(dark.rigId == rig.id)
        #expect(dark.pausable == true)

        let bias = try await client.captureBiasSequence(rigId: rig.id, count: 5)
        #expect(bias.script == "capture_bias_sequence")

        let flat = try await client.captureFlatSequence(
            rigId: rig.id,
            filterName: "Ha",
            focusPosition: 1000,
            exposureSeconds: 1,
            count: 5
        )
        #expect(flat.script == "capture_flat_sequence")

        let light = try await client.captureLightSequence(
            rigId: rig.id,
            ra: 5.5,
            dec: 20,
            filterName: "Ha",
            focusPosition: 1000,
            exposureSeconds: 60,
            count: 5
        )
        #expect(light.script == "capture_light_sequence")

        await client.disconnect()
    }

    @Test(
        "wrapper argument keys match each script's declared parameters",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func argumentKeysMatchDeclaredParameters() async throws {
        let client = try await connectedTestClient()

        let dark = try await client.getScript(id: "capture_dark_sequence")
        #expect(Set(dark.parameters.keys) == ["targetTempC", "exposureSeconds", "count"])

        let bias = try await client.getScript(id: "capture_bias_sequence")
        #expect(Set(bias.parameters.keys) == ["exposureSeconds", "count"])

        let flat = try await client.getScript(id: "capture_flat_sequence")
        #expect(
            Set(flat.parameters.keys)
                == ["filterName", "focusPosition", "exposureSeconds", "count", "gain", "offset"]
        )

        let light = try await client.getScript(id: "capture_light_sequence")
        #expect(
            Set(light.parameters.keys)
                == ["ra", "dec", "objectName", "filterName", "focusPosition", "targetTempC", "exposureSeconds", "count"]
        )

        await client.disconnect()
    }
}

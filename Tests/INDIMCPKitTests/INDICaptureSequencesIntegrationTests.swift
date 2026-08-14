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

        let calibrationSet = try await client.captureSensorCalibrationSet(
            rigId: rig.id,
            flatExposureSeconds: 1,
            biasCount: 5,
            flatCount: 5,
            darkCount: 5
        )
        #expect(calibrationSet.script == "capture_sensor_calibration_set")
        #expect(calibrationSet.rigId == rig.id)
        #expect(calibrationSet.pausable == true)

        // Every assertion above either omits gain/offset entirely or only checks the script's
        // declared parameter *names* (`argumentKeysMatchDeclaredParameters`) — neither exercises
        // the `if let gain`/`if let offset` branches that actually thread a supplied value into
        // the request. A wrong `Value` case (or a typo'd key) for either would still pass both of
        // those, since a mismatched key/type here surfaces as the server rejecting the run against
        // the script's own JSON-schema-validated parameters, not as a Swift-side compile or decode
        // failure — so this has to be a live call that actually succeeds. Reuses `rig` (rather
        // than saving a second one) deliberately: a second concurrent `saveRig` call in this same
        // suite hit a real INDIMCP-server race (`rig_store.save_rig`'s `load_rigs()` reloads the
        // whole rigs directory into one shared, unlocked dict — two concurrent saves can each see
        // a directory snapshot that doesn't yet include the other's just-written file, so one call
        // can lose the race and its own `get_rig` lookup then fails with "Unknown rig").
        let calibrationSetWithOptionalParameters = try await client.captureSensorCalibrationSet(
            rigId: rig.id,
            flatExposureSeconds: 1,
            biasCount: 2,
            flatCount: 2,
            darkCount: 2,
            gain: 100,
            offset: 10,
            biasExposureSeconds: 0.001
        )
        #expect(calibrationSetWithOptionalParameters.script == "capture_sensor_calibration_set")
        #expect(calibrationSetWithOptionalParameters.rigId == rig.id)

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
        #expect(Set(flat.parameters.keys) == ["filterName", "focusPosition", "exposureSeconds", "count"])

        let light = try await client.getScript(id: "capture_light_sequence")
        #expect(
            Set(light.parameters.keys)
                == ["ra", "dec", "objectName", "filterName", "focusPosition", "targetTempC", "exposureSeconds", "count"]
        )

        let calibrationSet = try await client.getScript(id: "capture_sensor_calibration_set")
        #expect(
            Set(calibrationSet.parameters.keys)
                == ["gain", "offset", "biasExposureSeconds", "flatExposureSeconds", "biasCount", "flatCount", "darkCount"]
        )

        await client.disconnect()
    }
}

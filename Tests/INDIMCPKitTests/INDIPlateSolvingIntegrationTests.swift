import Foundation
import Testing

@testable import INDIMCPKit

/// Exercises `runPlateSolveRig` against a real, running INDIMCP-server.
///
/// Skipped unless `INDIMCP_TEST_SERVER_URL` is set — see `INDIServerManagementIntegrationTests`
/// for how to run this manually. Run the server from the actual INDIMCP-server checkout, since
/// `plate_solve_rig` is a built-in script that must be loaded. None of these devices are actually
/// connected, so no run here actually solves a frame — same
/// argument-key-vs-declared-parameters limitation `INDICaptureSequencesIntegrationTests` works
/// around the same way.
@Suite("INDI plate solving (live server)")
struct INDIPlateSolvingIntegrationTests {
    @Test(
        "runPlateSolveRig starts the plate_solve_rig script against the given rig",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func startsPlateSolveScript() async throws {
        let client = try await connectedTestClient()

        let rig = Rig(
            id: "indimcpkit-test-\(UUID().uuidString)",
            name: "Plate Solve Test Rig",
            components: [
                Component(role: .mount, id: "mnt1", device: "Not Connected Mount"),
                Component(role: .camera, id: "cam1", device: "Not Connected Camera"),
            ]
        )
        _ = try await client.saveRig(rig)

        let started = try await client.runPlateSolveRig(rigId: rig.id, exposureSeconds: 1)
        #expect(started.script == "plate_solve_rig")
        #expect(started.rigId == rig.id)
        #expect(started.pausable == false)

        await client.disconnect()
    }

    @Test(
        "wrapper argument keys match the script's declared parameters",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func argumentKeysMatchDeclaredParameters() async throws {
        let client = try await connectedTestClient()

        let script = try await client.getScript(id: "plate_solve_rig")
        #expect(
            Set(script.parameters.keys)
                == Set([
                    "exposureSeconds", "syncMount", "toleranceArcsec", "maxAttempts",
                    "timeoutSeconds", "binningX", "binningY", "frameX", "frameY", "frameWidth",
                    "frameHeight",
                ])
        )

        await client.disconnect()
    }
}

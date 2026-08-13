import Foundation
import Testing

@testable import INDIMCPKit

/// Exercises `INDIScripts` against a real, running INDIMCP-server.
///
/// Skipped unless `INDIMCP_TEST_SERVER_URL` is set — see `INDIServerManagementIntegrationTests`
/// for how to run this manually. Unlike the rig/observatory suites, run the server from the
/// actual INDIMCP-server checkout (not an empty scratch directory) for this one: built-in scripts
/// (`park`, `slew`, ...) only load from that repo's `scripts/` directory, and `getBuiltInScript`
/// below needs one to exist to verify decoding against a script with real, complex `steps` data.
/// `saveScript` uploads land in `user_scripts/`, a separate, gitignored directory from the
/// checked-in `scripts/` — safe to run repeatedly against the real checkout without polluting or
/// colliding with anything tracked.
@Suite("INDI scripts (live server)")
struct INDIScriptsIntegrationTests {
    @Test(
        "getScript decodes a real built-in script's opaque steps",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func getBuiltInScript() async throws {
        let client = try await connectedTestClient()

        let park = try await client.getScript(id: "park")
        #expect(park.id == "park")
        #expect(park.pausable == false)
        #expect(!park.steps.isEmpty)

        let slew = try await client.getScript(id: "slew")
        #expect(slew.parameters["ra"]?.type == .number)
        #expect(slew.parameters["ra"]?.required == true)
        #expect(slew.parameters["dec"]?.type == .number)

        await client.disconnect()
    }

    @Test(
        "listScripts includes the built-in library",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func listIncludesBuiltIns() async throws {
        let client = try await connectedTestClient()

        let scripts = try await client.listScripts()
        #expect(scripts.contains { $0.id == "park" })

        await client.disconnect()
    }

    @Test(
        "save, then get, an uploaded script; overwrite protection holds",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func saveAndOverwriteProtection() async throws {
        let client = try await connectedTestClient()

        let script = Script(
            id: "indimcpkit-test-\(UUID().uuidString)",
            name: "INDIMCPKit Test Script",
            pausable: false,
            steps: []
        )

        let saved = try await client.saveScript(script)
        #expect(saved == script)

        let fetched = try await client.getScript(id: script.id)
        #expect(fetched == script)

        await #expect(throws: INDIMCPClientError.self) {
            _ = try await client.saveScript(script)
        }

        let renamed = Script(id: script.id, name: "Renamed", pausable: false, steps: [])
        let overwritten = try await client.saveScript(renamed, overwrite: true)
        #expect(overwritten == renamed)

        await client.disconnect()
    }

    @Test(
        "save refuses an id that collides with a built-in script",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func saveRefusesBuiltInCollision() async throws {
        let client = try await connectedTestClient()

        let collidingScript = Script(id: "park", name: "Fake park", pausable: false, steps: [])

        await #expect(throws: INDIMCPClientError.self) {
            _ = try await client.saveScript(collidingScript)
        }

        await client.disconnect()
    }
}

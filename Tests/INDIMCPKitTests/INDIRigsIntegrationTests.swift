import Foundation
import Testing

@testable import INDIMCPKit

/// Exercises `INDIRigs` against a real, running INDIMCP-server.
///
/// Skipped unless `INDIMCP_TEST_SERVER_URL` is set — see `INDIServerManagementIntegrationTests`
/// for how to run this manually. Unlike the other integration suites, rig storage writes
/// `<rig.id>.yaml` files to a `rigs/` directory relative to the server process's working
/// directory — run the server from a scratch/throwaway directory (not a checkout with real rig
/// files) so this doesn't collide with or clutter anything real. INDIMCP-server has no
/// `delete_rig` tool, so **never point this at a server whose `rigs/` directory you care about**:
/// every run of this suite leaves one or more `indimcpkit-test-<uuid>.yaml` files behind with no
/// way to remove them via the API — only a scratch directory you can throw away afterwards makes
/// that harmless.
///
/// Uses a UUID-suffixed rig id and never asserts the exact contents of `list_rigs`, since a
/// long-lived manual server may already have other rigs saved.
@Suite("INDI rigs (live server)")
struct INDIRigsIntegrationTests {
    @Test(
        "save, then get and list, a rig",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func saveGetAndList() async throws {
        let client = try await connectedTestClient()

        let rig = Self.makeRig(id: "indimcpkit-test-\(UUID().uuidString)")

        let saved = try await client.saveRig(rig)
        #expect(saved == rig)

        let fetched = try await client.getRig(id: rig.id)
        #expect(fetched == rig)

        let rigs = try await client.listRigs()
        #expect(rigs.contains(RigSummary(id: rig.id, name: rig.name)))

        await client.disconnect()
    }

    @Test(
        "save refuses to replace an existing rig unless overwrite is set",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func saveRefusesToOverwriteByDefault() async throws {
        let client = try await connectedTestClient()

        let rig = Self.makeRig(id: "indimcpkit-test-\(UUID().uuidString)")
        _ = try await client.saveRig(rig)

        // A second save of the same id without overwrite must fail — this is the data-loss
        // protection saveRig's own doc comment promises: reusing an id should never silently
        // destroy a previously saved rig.
        await #expect(throws: INDIMCPClientError.self) {
            _ = try await client.saveRig(rig)
        }

        // With overwrite explicitly set, the same id must succeed.
        let renamed = Rig(id: rig.id, name: "Renamed", components: rig.components)
        let overwritten = try await client.saveRig(renamed, overwrite: true)
        #expect(overwritten == renamed)

        await client.disconnect()
    }

    private static func makeRig(id: String) -> Rig {
        Rig(
            id: id,
            name: "INDIMCPKit Test Rig",
            components: [
                Component(role: .camera, id: "cam1", device: "CCD Simulator", pixelsX: 1920, pixelsY: 1080),
                Component(role: .filterWheel, id: "fw1", slots: [1: "Ha", 2: "OIII"]),
            ]
        )
    }
}

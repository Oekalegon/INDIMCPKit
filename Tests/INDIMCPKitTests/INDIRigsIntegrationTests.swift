import Foundation
import Testing

@testable import INDIMCPKit

/// Exercises `INDIRigs` against a real, running INDIMCP-server.
///
/// Skipped unless `INDIMCP_TEST_SERVER_URL` is set — see `INDIServerManagementIntegrationTests`
/// for how to run this manually. Unlike the other integration suites, rig storage writes
/// `<rig.id>.yaml` files to a `rigs/` directory relative to the server process's working
/// directory — run the server from a scratch/throwaway directory (not a checkout with real rig
/// files) so this doesn't collide with or clutter anything real.
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
        let urlString = ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"]!
        let client = INDIMCPClient(endpoint: try #require(URL(string: urlString)))
        try await client.connect()

        let rigID = "indimcpkit-test-\(UUID().uuidString)"
        let rig = Rig(
            id: rigID,
            name: "INDIMCPKit Test Rig",
            components: [
                Component(role: .camera, id: "cam1", device: "CCD Simulator", pixelsX: 1920, pixelsY: 1080),
                Component(role: .filterWheel, id: "fw1", slots: [1: "Ha", 2: "OIII"]),
            ]
        )

        let saved = try await client.saveRig(rig)
        #expect(saved == rig)

        let fetched = try await client.getRig(id: rigID)
        #expect(fetched == rig)

        let rigs = try await client.listRigs()
        #expect(rigs.contains(RigSummary(id: rigID, name: "INDIMCPKit Test Rig")))

        await client.disconnect()
    }
}

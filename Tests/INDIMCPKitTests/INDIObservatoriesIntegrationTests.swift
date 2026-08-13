import Foundation
import Testing

@testable import INDIMCPKit

/// Exercises `INDIObservatories` against a real, running INDIMCP-server.
///
/// Skipped unless `INDIMCP_TEST_SERVER_URL` is set — see `INDIServerManagementIntegrationTests`
/// for how to run this manually. Observatory storage writes `<observatory.id>.yaml` files
/// relative to the server's working directory — see `INDIRigsIntegrationTests`'s doc comment for
/// why this must be run from a scratch/throwaway directory, and for why there's no way to clean
/// these up via the API (no `delete_observatory` tool any more than there's a `delete_rig` one).
@Suite("INDI observatories (live server)")
struct INDIObservatoriesIntegrationTests {
    @Test(
        "save, then get and list, an observatory",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func saveGetAndList() async throws {
        let client = try await connectedTestClient()

        let observatory = Self.makeObservatory(id: "indimcpkit-test-\(UUID().uuidString)")

        let saved = try await client.saveObservatory(observatory)
        #expect(saved == observatory)

        let fetched = try await client.getObservatory(id: observatory.id)
        #expect(fetched == observatory)

        let observatories = try await client.listObservatories()
        #expect(observatories.contains(ObservatorySummary(id: observatory.id, name: observatory.name)))

        await client.disconnect()
    }

    @Test(
        "save refuses to replace an existing observatory unless overwrite is set",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func saveRefusesToOverwriteByDefault() async throws {
        let client = try await connectedTestClient()

        let observatory = Self.makeObservatory(id: "indimcpkit-test-\(UUID().uuidString)")
        _ = try await client.saveObservatory(observatory)

        await #expect(throws: INDIMCPClientError.self) {
            _ = try await client.saveObservatory(observatory)
        }

        let renamed = Observatory(
            id: observatory.id,
            name: "Renamed",
            latitudeDeg: observatory.latitudeDeg,
            longitudeDeg: observatory.longitudeDeg
        )
        let overwritten = try await client.saveObservatory(renamed, overwrite: true)
        #expect(overwritten == renamed)

        await client.disconnect()
    }

    @Test(
        "draftObservatory flags no connected GEOGRAPHIC_COORD device",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func draftWithNoDevices() async throws {
        try await IndiServerTestLock.withLock {
            let client = try await connectedTestClient()
            _ = try await client.startINDIServer()
            _ = try await client.startINDIMessaging()

            let draft = try await client.draftObservatory()
            #expect(draft.latitudeDeg == nil)
            #expect(draft.longitudeDeg == nil)
            #expect(!draft.notes.isEmpty)

            _ = try await client.stopINDIServer()
            await client.disconnect()
        }
    }

    private static func makeObservatory(id: String) -> Observatory {
        Observatory(id: id, name: "INDIMCPKit Test Observatory", latitudeDeg: 52.1, longitudeDeg: 5.1, elevationMeters: 10)
    }
}

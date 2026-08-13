import Foundation
import Testing

@testable import INDIMCPKit

/// Exercises `INDIRigReconciliation` against a real, running INDIMCP-server with a real
/// `indiserver` process behind it.
///
/// Skipped unless `INDIMCP_TEST_SERVER_URL` is set — see `INDIServerManagementIntegrationTests`
/// for how to run this manually. Rig storage writes `<rig.id>.yaml` files relative to the
/// server's working directory — see `INDIRigsIntegrationTests`'s doc comment for why this must
/// be run from a scratch/throwaway directory.
///
/// None of these tools can be exercised with a real, agreeing device here: doing so would need an
/// actual connected filter wheel driver, and the INDI driver catalog that would start one only
/// exists on the target Raspberry Pi (see `INDIDriverManagementIntegrationTests`). This suite
/// verifies the shape of the "no devices connected" case instead — suggestRig/draftRig return
/// empty results, checkRig reports every configured device as missing, and syncFilterNames fails
/// with the disagreement it's designed to catch.
///
/// Bodies run under `IndiServerTestLock`, since `INDIServerManagementIntegrationTests` and
/// `INDIMessagingIntegrationTests` also start/stop this same shared `indiserver` process and
/// Swift Testing runs different suites (and, within one, different tests) concurrently by
/// default — see that lock's doc comment.
@Suite("INDI rig reconciliation (live server)")
struct INDIRigReconciliationIntegrationTests {
    @Test(
        "suggestRig and draftRig report no matches with no devices connected",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func suggestAndDraftWithNoDevices() async throws {
        try await IndiServerTestLock.withLock {
            let client = try await connectedTestClient()
            _ = try await client.startINDIServer()
            _ = try await client.startINDIMessaging()

            // Doesn't assert suggestions.isEmpty: suggestRig scores every rig currently loaded on
            // the server, including ones other tests in this suite may have saved — the one
            // invariant that holds regardless of how many rigs exist is that none of them can
            // have a *matched* device, since no INDI devices are connected at all in this
            // environment (see the suite's doc comment).
            let suggestions = try await client.suggestRig()
            #expect(suggestions.allSatisfy { $0.matched.isEmpty })

            let draft = try await client.draftRig()
            #expect(draft.components.isEmpty)

            _ = try await client.stopINDIServer()
            await client.disconnect()
        }
    }

    @Test(
        "checkRig reports every configured device as missing when none are connected",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func checkRigWithNoDevicesConnected() async throws {
        try await IndiServerTestLock.withLock {
            let client = try await connectedTestClient()
            _ = try await client.startINDIServer()
            _ = try await client.startINDIMessaging()

            let rig = Rig(
                id: "indimcpkit-test-\(UUID().uuidString)",
                name: "Reconciliation Test Rig",
                components: [
                    Component(role: .camera, id: "cam1", device: "NotConnectedCam"),
                    Component(role: .filterWheel, id: "fw1", device: "NotConnectedFW", slots: [1: "Ha"]),
                ]
            )
            _ = try await client.saveRig(rig)

            let check = try await client.checkRig(id: rig.id)
            #expect(check.ok == false)
            #expect(check.present.isEmpty)
            #expect(Set(check.missing) == ["cam1", "fw1"])

            // Neither device is actually connected, so pushing/adopting filter names must fail —
            // this is the disagreement syncFilterNames/adoptFilterNamesFromDriver exist to catch.
            await #expect(throws: INDIMCPClientError.self) {
                _ = try await client.syncFilterNames(rigID: rig.id, role: "filterWheel")
            }
            await #expect(throws: INDIMCPClientError.self) {
                _ = try await client.adoptFilterNamesFromDriver(rigID: rig.id, role: "filterWheel")
            }

            _ = try await client.stopINDIServer()
            await client.disconnect()
        }
    }
}

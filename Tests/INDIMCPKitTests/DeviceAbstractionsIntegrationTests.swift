import Foundation
import Testing

@testable import INDIMCPKit

/// Exercises the `Mount`/`Camera`/`FilterWheel`/`Focuser` device-type abstractions — specifically
/// their `ensureConnected` pre-check — against a real, running INDIMCP-server.
///
/// Skipped unless `INDIMCP_TEST_SERVER_URL` is set — see `INDIServerManagementIntegrationTests`
/// for how to run this manually. Run the server from the actual INDIMCP-server checkout (like
/// `INDIDeviceControlIntegrationTests`), since `connect`/`disconnect` must be loaded for the
/// skip-the-check test to actually reach a real tool call.
@Suite("Device abstractions (live server)")
struct DeviceAbstractionsIntegrationTests {
    @Test(
        "a command throws noComponentForRole when the rig has no matching component",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func throwsWhenNoComponentForRole() async throws {
        let client = try await connectedTestClient()

        let rig = Rig(
            id: "indimcpkit-test-\(UUID().uuidString)",
            name: "No Mount Rig",
            components: [Component(role: .camera, id: "cam1", device: "Not Connected Camera")]
        )
        _ = try await client.saveRig(rig)

        await #expect(throws: DeviceControlError.self) {
            _ = try await client.mount(rigId: rig.id).park()
        }

        await client.disconnect()
    }

    @Test(
        "a command throws deviceNotConnected when the rig's component isn't connected",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func throwsWhenDeviceNotConnected() async throws {
        try await IndiServerTestLock.withLock {
            let client = try await connectedTestClient()
            _ = try await client.startINDIServer()
            _ = try await client.startINDIMessaging()

            let rig = Rig(
                id: "indimcpkit-test-\(UUID().uuidString)",
                name: "Unconnected Mount Rig",
                components: [Component(role: .mount, id: "mnt1", device: "Not Connected Mount")]
            )
            _ = try await client.saveRig(rig)

            await #expect(throws: DeviceControlError.self) {
                _ = try await client.mount(rigId: rig.id).park()
            }

            _ = try await client.stopINDIServer()
            await client.disconnect()
        }
    }

    @Test(
        "connect/disconnect skip the connectivity check",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func connectAndDisconnectSkipTheCheck() async throws {
        let client = try await connectedTestClient()

        let rig = Rig(
            id: "indimcpkit-test-\(UUID().uuidString)",
            name: "Connect Skip Check Rig",
            components: [Component(role: .mount, id: "mnt1", device: "Not Connected Mount")]
        )
        _ = try await client.saveRig(rig)

        let mount = client.mount(rigId: rig.id)
        let connected = try await mount.connect()
        #expect(connected.script == "connect")
        let disconnected = try await mount.disconnect()
        #expect(disconnected.script == "disconnect")

        await client.disconnect()
    }
}

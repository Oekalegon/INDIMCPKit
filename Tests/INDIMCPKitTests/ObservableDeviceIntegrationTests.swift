import Foundation
import Testing

@testable import INDIMCPKit

/// Exercises `ObservableDevice` against a real, running INDIMCP-server.
///
/// This dev environment has no real INDI driver catalog (see `DeviceAbstractionsIntegrationTests`'
/// doc comment) — no property events ever actually flow for a role with nothing connected, so
/// this can't exercise the live-update or periodic-resync paths for real. It's scoped to what's
/// verifiable without a driver: `start()` correctly resolving (or failing to resolve) `role` to a
/// device name via the rig, and the resulting `deviceName`/`lastError` state.
@Suite("Observable device (live server)")
struct ObservableDeviceIntegrationTests {
    @Test(
        "start reports an error when the rig has no component for the role",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func startReportsErrorWhenNoComponentForRole() async throws {
        let client = try await connectedTestClient()

        let rig = Rig(
            id: "indimcpkit-test-\(UUID().uuidString)",
            name: "No Camera Rig (ObservableDevice)",
            components: [Component(role: .mount, id: "mnt1", device: "Not Connected Mount")]
        )
        _ = try await client.saveRig(rig)

        let device = await ObservableDevice(client: client, rigId: rig.id, role: .camera)
        await device.start(resyncInterval: nil)

        #expect(await device.deviceName == nil)
        #expect(await device.lastError != nil)
        #expect(await device.properties.isEmpty)

        await device.stop()
        await client.disconnect()
    }

    @Test(
        "start resolves the role to its device name via the rig",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func startResolvesDeviceName() async throws {
        try await IndiServerTestLock.withLock {
            let client = try await connectedTestClient()
            _ = try await client.startINDIServer()
            _ = try await client.startINDIMessaging()

            let rig = Rig(
                id: "indimcpkit-test-\(UUID().uuidString)",
                name: "Camera Rig (ObservableDevice)",
                components: [Component(role: .camera, id: "cam1", device: "Not Connected Camera")]
            )
            _ = try await client.saveRig(rig)

            let device = await ObservableDevice(client: client, rigId: rig.id, role: .camera)
            await device.start(resyncInterval: nil)

            #expect(await device.deviceName == "Not Connected Camera")
            // No driver actually running for "Not Connected Camera" — getDeviceProperties itself
            // may or may not error depending on server behavior for an unrecognized device name,
            // but deviceName resolution (the thing this test actually checks) doesn't depend on
            // that succeeding.

            await device.stop()
            _ = try await client.stopINDIServer()
            await client.disconnect()
        }
    }
}

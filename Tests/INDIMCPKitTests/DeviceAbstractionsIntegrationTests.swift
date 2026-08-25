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
        "isDeviceConnected reports false, not throwing, when the rig has no matching component",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func isDeviceConnectedFalseWhenNoComponentForRole() async throws {
        let client = try await connectedTestClient()

        let rig = Rig(
            id: "indimcpkit-test-\(UUID().uuidString)",
            name: "No Mount Rig (isDeviceConnected)",
            components: [Component(role: .camera, id: "cam1", device: "Not Connected Camera")]
        )
        _ = try await client.saveRig(rig)

        // Unlike ensureConnected (which throws noComponentForRole here), isDeviceConnected
        // doesn't distinguish "no component" from "component present but not connected" — both
        // just report false, since it's meant as a plain yes/no UI signal, not a diagnostic.
        let connected = try await client.isDeviceConnected(role: .mount, rigId: rig.id)
        #expect(connected == false)

        await client.disconnect()
    }

    @Test(
        "isDeviceConnected reports false when the rig's component isn't connected",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func isDeviceConnectedFalseWhenDeviceNotConnected() async throws {
        try await IndiServerTestLock.withLock {
            let client = try await connectedTestClient()
            _ = try await client.startINDIServer()
            _ = try await client.startINDIMessaging()

            let rig = Rig(
                id: "indimcpkit-test-\(UUID().uuidString)",
                name: "Unconnected Mount Rig (isDeviceConnected)",
                components: [Component(role: .mount, id: "mnt1", device: "Not Connected Mount")]
            )
            _ = try await client.saveRig(rig)

            let connected = try await client.mount(rigId: rig.id).isConnected()
            #expect(connected == false)

            _ = try await client.stopINDIServer()
            await client.disconnect()
        }
    }

    @Test(
        "camera isCoolerOn reports nil when the rig's camera component has no device name",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func cameraIsCoolerOnNilWhenNoDeviceName() async throws {
        let client = try await connectedTestClient()

        let rig = Rig(
            id: "indimcpkit-test-\(UUID().uuidString)",
            name: "Camera With No Device Name",
            components: [Component(role: .camera, id: "cam1")]
        )
        _ = try await client.saveRig(rig)

        let isCoolerOn = try await client.camera(rigId: rig.id).isCoolerOn()
        #expect(isCoolerOn == nil)

        await client.disconnect()
    }

    @Test(
        "camera isCoolerOn reports nil when no CCD_COOLER event has ever been observed",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func cameraIsCoolerOnNilWhenNoCoolerEventObserved() async throws {
        try await IndiServerTestLock.withLock {
            let client = try await connectedTestClient()
            _ = try await client.startINDIServer()
            _ = try await client.startINDIMessaging()

            let rig = Rig(
                id: "indimcpkit-test-\(UUID().uuidString)",
                name: "Camera Never Toggled Cooler",
                components: [Component(role: .camera, id: "cam1", device: "Not Connected Camera")]
            )
            _ = try await client.saveRig(rig)

            let isCoolerOn = try await client.camera(rigId: rig.id).isCoolerOn()
            #expect(isCoolerOn == nil)

            _ = try await client.stopINDIServer()
            await client.disconnect()
        }
    }

    @Test(
        "camera property getters report nil when the rig's camera component has no device name",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func cameraPropertyGettersNilWhenNoDeviceName() async throws {
        let client = try await connectedTestClient()

        let rig = Rig(
            id: "indimcpkit-test-\(UUID().uuidString)",
            name: "Camera Properties, No Device Name",
            components: [Component(role: .camera, id: "cam1")]
        )
        _ = try await client.saveRig(rig)

        let camera = client.camera(rigId: rig.id)
        #expect(try await camera.currentTempC() == nil)
        #expect(try await camera.targetTempC() == nil)
        #expect(try await camera.coolerPowerPercent() == nil)
        #expect(try await camera.exposureCountdownSeconds() == nil)
        #expect(try await camera.gain() == nil)
        #expect(try await camera.offset() == nil)
        #expect(try await camera.binning() == nil)
        #expect(try await camera.frame() == nil)
        #expect(try await camera.bitDepth() == nil)

        await client.disconnect()
    }

    @Test(
        "camera property setters throw deviceNotConnected when the rig's camera isn't connected",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func cameraPropertySettersThrowWhenNotConnected() async throws {
        try await IndiServerTestLock.withLock {
            let client = try await connectedTestClient()
            _ = try await client.startINDIServer()
            _ = try await client.startINDIMessaging()

            let rig = Rig(
                id: "indimcpkit-test-\(UUID().uuidString)",
                name: "Camera Property Setters, Not Connected",
                components: [Component(role: .camera, id: "cam1", device: "Not Connected Camera")]
            )
            _ = try await client.saveRig(rig)

            let camera = client.camera(rigId: rig.id)
            await #expect(throws: DeviceControlError.self) { try await camera.setTargetTempC(-10) }
            await #expect(throws: DeviceControlError.self) { try await camera.setGain(100) }
            await #expect(throws: DeviceControlError.self) { try await camera.setOffset(10) }
            await #expect(throws: DeviceControlError.self) { try await camera.setBinning(x: 2, y: 2) }
            await #expect(throws: DeviceControlError.self) {
                try await camera.setFrame(x: 0, y: 0, width: 100, height: 100)
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

    // MARK: - Camera, FilterWheel, Focuser
    //
    // Each type independently calls ensureConnected(role: .<its own role>, ...) before forwarding
    // to its raw INDIMCPClient call — a copy-paste role mismatch (e.g. Camera accidentally
    // checking .mount) would compile fine and only a test exercising that specific type would
    // catch it. Mount's tests above can't cover this, since Mount never touches this code.

    @Test(
        "camera commands throw noComponentForRole when the rig has no camera component",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func cameraThrowsWhenNoComponentForRole() async throws {
        let client = try await connectedTestClient()

        let rig = Rig(
            id: "indimcpkit-test-\(UUID().uuidString)",
            name: "No Camera Rig",
            components: [Component(role: .mount, id: "mnt1", device: "Not Connected Mount")]
        )
        _ = try await client.saveRig(rig)

        await #expect(throws: DeviceControlError.self) {
            _ = try await client.camera(rigId: rig.id).coolerOn()
        }

        await client.disconnect()
    }

    @Test(
        "camera connect/disconnect skip the connectivity check",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func cameraConnectAndDisconnectSkipTheCheck() async throws {
        let client = try await connectedTestClient()

        let rig = Rig(
            id: "indimcpkit-test-\(UUID().uuidString)",
            name: "Camera Connect Skip Check Rig",
            components: [Component(role: .camera, id: "cam1", device: "Not Connected Camera")]
        )
        _ = try await client.saveRig(rig)

        let camera = client.camera(rigId: rig.id)
        let connected = try await camera.connect()
        #expect(connected.script == "connect")
        let disconnected = try await camera.disconnect()
        #expect(disconnected.script == "disconnect")

        await client.disconnect()
    }

    @Test(
        "filter wheel commands throw noComponentForRole when the rig has no filterWheel component",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func filterWheelThrowsWhenNoComponentForRole() async throws {
        let client = try await connectedTestClient()

        let rig = Rig(
            id: "indimcpkit-test-\(UUID().uuidString)",
            name: "No Filter Wheel Rig",
            components: [Component(role: .mount, id: "mnt1", device: "Not Connected Mount")]
        )
        _ = try await client.saveRig(rig)

        await #expect(throws: DeviceControlError.self) {
            _ = try await client.filterWheel(rigId: rig.id).selectFilter("Ha")
        }

        await client.disconnect()
    }

    @Test(
        "filter wheel connect/disconnect skip the connectivity check",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func filterWheelConnectAndDisconnectSkipTheCheck() async throws {
        let client = try await connectedTestClient()

        let rig = Rig(
            id: "indimcpkit-test-\(UUID().uuidString)",
            name: "Filter Wheel Connect Skip Check Rig",
            components: [Component(role: .filterWheel, id: "fw1", device: "Not Connected FW", slots: [1: "Ha"])]
        )
        _ = try await client.saveRig(rig)

        let filterWheel = client.filterWheel(rigId: rig.id)
        let connected = try await filterWheel.connect()
        #expect(connected.script == "connect")
        let disconnected = try await filterWheel.disconnect()
        #expect(disconnected.script == "disconnect")

        await client.disconnect()
    }

    @Test(
        "filter wheel property getters report empty/nil when the rig has no filterWheel component",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func filterWheelPropertyGettersEmptyWhenNoComponentForRole() async throws {
        let client = try await connectedTestClient()

        let rig = Rig(
            id: "indimcpkit-test-\(UUID().uuidString)",
            name: "No Filter Wheel Rig (properties)",
            components: [Component(role: .mount, id: "mnt1", device: "Not Connected Mount")]
        )
        _ = try await client.saveRig(rig)

        let filterWheel = client.filterWheel(rigId: rig.id)
        #expect(try await filterWheel.currentFilterName() == nil)
        #expect(try await filterWheel.filterNames() == [:])
        #expect(try await filterWheel.liveFilterNames() == [:])

        await client.disconnect()
    }

    @Test(
        "setFilterName round-trips through saveRig and leaves the rig's other slots untouched",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func filterWheelSetFilterNameRoundTrips() async throws {
        let client = try await connectedTestClient()

        let rig = Rig(
            id: "indimcpkit-test-\(UUID().uuidString)",
            name: "Filter Wheel setFilterName Rig",
            components: [
                Component(role: .filterWheel, id: "fw1", device: "Not Connected FW", slots: [1: "Ha", 2: "OIII"])
            ]
        )
        _ = try await client.saveRig(rig)

        let filterWheel = client.filterWheel(rigId: rig.id)
        let updated = try await filterWheel.setFilterName(slot: 3, name: "SII")
        #expect(updated == [1: "Ha", 2: "OIII", 3: "SII"])

        let refetched = try await filterWheel.filterNames()
        #expect(refetched == [1: "Ha", 2: "OIII", 3: "SII"])

        await client.disconnect()
    }

    @Test(
        "setFilterName throws ambiguousComponentForRole when the rig has two filterWheel components",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func filterWheelSetFilterNameThrowsWhenAmbiguous() async throws {
        let client = try await connectedTestClient()

        let rig = Rig(
            id: "indimcpkit-test-\(UUID().uuidString)",
            name: "Two Filter Wheels Rig",
            components: [
                Component(role: .filterWheel, id: "fw1", device: "FW One", slots: [1: "Ha"]),
                Component(role: .filterWheel, id: "fw2", device: "FW Two", slots: [1: "OIII"]),
            ]
        )
        _ = try await client.saveRig(rig)

        await #expect(throws: DeviceControlError.self) {
            _ = try await client.filterWheel(rigId: rig.id).setFilterName(slot: 1, name: "SII")
        }

        await client.disconnect()
    }

    @Test(
        "focuser commands throw noComponentForRole when the rig has no focuser component",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func focuserThrowsWhenNoComponentForRole() async throws {
        let client = try await connectedTestClient()

        let rig = Rig(
            id: "indimcpkit-test-\(UUID().uuidString)",
            name: "No Focuser Rig",
            components: [Component(role: .mount, id: "mnt1", device: "Not Connected Mount")]
        )
        _ = try await client.saveRig(rig)

        await #expect(throws: DeviceControlError.self) {
            _ = try await client.focuser(rigId: rig.id).setFocusPosition(1000)
        }

        await client.disconnect()
    }

    @Test(
        "focuser connect/disconnect skip the connectivity check",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func focuserConnectAndDisconnectSkipTheCheck() async throws {
        let client = try await connectedTestClient()

        let rig = Rig(
            id: "indimcpkit-test-\(UUID().uuidString)",
            name: "Focuser Connect Skip Check Rig",
            components: [Component(role: .focuser, id: "foc1", device: "Not Connected Focuser")]
        )
        _ = try await client.saveRig(rig)

        let focuser = client.focuser(rigId: rig.id)
        let connected = try await focuser.connect()
        #expect(connected.script == "connect")
        let disconnected = try await focuser.disconnect()
        #expect(disconnected.script == "disconnect")

        await client.disconnect()
    }
}

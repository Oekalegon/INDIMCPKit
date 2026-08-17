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

    /// Regression coverage for the unsubscribe race `stop()`'s own doc comment describes (fixed
    /// alongside the deadlock below — see `INDIMCPClient.unsubscribeFromResource`'s doc comment).
    /// `start()` itself calls `teardown()` first (see its own doc comment), so back-to-back
    /// `start()` calls exercise the identical stop-then-start sequence as an explicit `stop()`
    /// followed by `start()`.
    ///
    /// This dev environment has no real INDI driver catalog (see `DeviceAbstractionsIntegrationTests`'
    /// doc comment), so — same limitation `ObservableMessageStreamIntegrationTests`' own doc
    /// comment notes for the analogous stream — there's no way to confirm the live subscription
    /// itself survives each cycle without a real driver actually publishing property events. What
    /// *is* verifiable here: several rapid cycles each still resolve `deviceName` and complete
    /// without hanging, rather than one cycle's `start()` getting stuck awaiting an unsubscribe
    /// confirmation that never arrives.
    @Test(
        "rapid stop-then-start cycles each resolve the device name without hanging",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func rapidStopStartCyclesDoNotHang() async throws {
        try await IndiServerTestLock.withLock {
            let client = try await connectedTestClient()

            let rig = Rig(
                id: "indimcpkit-test-\(UUID().uuidString)",
                name: "Rapid Cycle Rig (ObservableDevice)",
                components: [Component(role: .camera, id: "cam1", device: "Not Connected Camera")]
            )
            _ = try await client.saveRig(rig)

            let device = await ObservableDevice(client: client, rigId: rig.id, role: .camera)

            for _ in 0..<5 {
                await device.start(resyncInterval: nil)
                #expect(await device.deviceName == "Not Connected Camera")
                await device.stop()
            }
            await device.start(resyncInterval: nil)
            #expect(await device.deviceName == "Not Connected Camera")

            await device.stop()
            await client.disconnect()
        }
    }

    /// Regression coverage for the client-side deadlock fixed alongside the unsubscribe race
    /// above — see `INDIMCPClient.subscribeToResourceUpdates`'s doc comment on its `onNotification`
    /// handler for the mechanism: awaiting a re-read inline on the swift-sdk `Client`'s single
    /// message-reading task blocked that task forever once *any* notification for a live
    /// subscription arrived, hanging every other in-flight or future request (the commit that
    /// fixed this observed `connect`, `getScriptStatus`, and server restart calls all hang once a
    /// live `messageEvents` subscription was active).
    ///
    /// `ObservableDevice` only ever subscribes to a *device*-scoped `messageEvents(device:)`, which
    /// needs a real driver to ever actually publish an event — unavailable here (see
    /// `DeviceAbstractionsIntegrationTests`' doc comment). The *unscoped* `indi://messages` stream
    /// this test subscribes to directly goes through the exact same `subscribeToResourceUpdates`
    /// notification-handling code `ObservableDevice`'s subscription does, and reliably receives at
    /// least one real notification just from `indiserver`'s own startup log messages (which carry
    /// no device name) once `startINDIServer`/`startINDIMessaging` run — see
    /// `ObservableMessageStreamIntegrationTests`' own doc comment on why those show up unscoped.
    /// That's enough to actually trigger the handler this regression is about, which a
    /// device-scoped subscription with no driver behind it never would.
    @Test(
        "a fired live-subscription notification doesn't block a later, unrelated tool call",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func liveNotificationDoesNotDeadlockLaterCalls() async throws {
        try await IndiServerTestLock.withLock {
            let client = try await connectedTestClient()

            let receivedWindow = ReceivedWindowFlag()
            let subscriptionTask = Task {
                for try await _ in client.messageEvents() {
                    await receivedWindow.markReceived()
                }
            }
            defer { subscriptionTask.cancel() }

            _ = try await client.startINDIServer()
            _ = try await client.startINDIMessaging()

            var sawNotification = false
            for _ in 0..<50 {
                if await receivedWindow.received {
                    sawNotification = true
                    break
                }
                try await Task.sleep(for: .milliseconds(200))
            }
            guard sawNotification else {
                Issue.record("No live notification observed after starting indiserver/messaging")
                _ = try await client.stopINDIServer()
                await client.disconnect()
                return
            }

            // Before the fix, the notification handler that just fired above would still be stuck
            // awaiting its own re-read forever, so this call would hang indefinitely too — raced
            // against a bounded timeout so a regression fails the assertion below instead of
            // hanging the whole suite.
            let completedInTime = try await withThrowingTaskGroup(of: Bool.self) { group in
                group.addTask {
                    _ = try await client.getINDIMessagingStatus()
                    return true
                }
                group.addTask {
                    try await Task.sleep(for: .seconds(15))
                    return false
                }
                let result = try await group.next() ?? false
                group.cancelAll()
                return result
            }
            #expect(completedInTime)

            _ = try await client.stopINDIMessaging()
            _ = try await client.stopINDIServer()
            await client.disconnect()
        }
    }
}

/// Records whether at least one window has been received from a live subscription — a plain
/// actor rather than `@MainActor` state, since the subscription-consuming `Task` in
/// `liveNotificationDoesNotDeadlockLaterCalls` isn't itself main-actor-isolated.
private actor ReceivedWindowFlag {
    private(set) var received = false
    func markReceived() { received = true }
}

import Foundation
import Observation

/// A rig-scoped device handle that keeps its property state live in memory, unlike
/// `Mount`/`Camera`/`FilterWheel`/`Focuser` (pure fire-a-command handles with no state of their
/// own). One generic class covers every role rather than a parallel `ObservableMount`/
/// `ObservableCamera`/... per device type, since the actual state-tracking logic — resolve role
/// to device name, snapshot, apply live updates — is identical regardless of which role it's for.
///
/// State is kept fresh two ways, matching `docs/Design.md#event-streams`'s own reconnect story
/// (a live subscription is best-effort, not a resilience mechanism):
/// - A full snapshot via `getDeviceProperties` on `start()` (call again after any reconnect —
///   this type doesn't own the connection and can't detect one on its own) and periodically
///   thereafter (`resyncInterval`), as a safety net against any live update silently missed.
/// - Incremental updates from `messageEvents(device:)` (IMCPKIT-14) applied as they arrive.
///
/// `@MainActor`-isolated, matching every other `@Observable` model in this kit's own test app
/// (`AppModel`, `CameraModel`, ...) — the realistic consumer is always a SwiftUI view, and the
/// live-update subscription already needs actor-isolated mutable state to update safely as events
/// arrive on their own `Task`.
@MainActor
@Observable
public final class ObservableDevice: DeviceHandle {
    /// The MCP client this device handle was obtained from.
    public let client: INDIMCPClient
    /// The id of the rig this device handle belongs to.
    public let rigId: String
    /// The role this device handle plays within its rig.
    public let role: Role

    /// The rig component's INDI device name for `role`, resolved on `start()` — `nil` until then,
    /// or if the rig has no component declaring `role` at all.
    public private(set) var deviceName: String?

    /// Every property this device currently reports, keyed by property (vector) name. Reflects
    /// the last `getDeviceProperties` snapshot, corrected by every `propertyDefinition`/
    /// `propertyUpdate`/`propertyDeleted` event observed since.
    public private(set) var properties: [String: DeviceProperty] = [:]

    /// Whether the most recent snapshot was confirmed live by the server (`DeviceProperties.
    /// refreshed`) rather than a fallback to a cached reading — see that type's own doc comment.
    public private(set) var isRefreshed = false

    /// The most recent error from either the snapshot or live-update path, if any. Not cleared
    /// automatically by a later success on the *other* path — a non-nil value here doesn't by
    /// itself mean `properties` is currently stale, just that *something* has failed at some
    /// point since the last `start()`.
    public private(set) var lastError: String?

    private var startTask: Task<Void, Never>?
    private var subscriptionTask: Task<Void, Never>?
    private var resyncTask: Task<Void, Never>?

    /// The device `beginSubscription` last subscribed `messageEvents` for, if any — recorded so
    /// `stop()` can explicitly unsubscribe that exact URI. See `stop()`'s doc comment for why this
    /// can't just rely on cancelling `subscriptionTask` and letting the stream's own cleanup fire.
    private var subscribedDevice: String?

    // No deinit cancelling these: `deinit` runs nonisolated even for a @MainActor class, and
    // can't touch MainActor-isolated stored properties to cancel them. Every task here captures
    // `self` weakly, so they stop mutating anything once this instance is gone — worst case they
    // linger briefly until their next loop iteration notices `self` is nil, not a real leak of
    // `self` itself. Call `stop()` explicitly before discarding an instance if you need the
    // subscription/resync to end deterministically rather than opportunistically.

    /// Creates a handle for rig `rigId`'s `role` component. Call `start()` to begin tracking its
    /// state.
    public init(client: INDIMCPClient, rigId: String, role: Role) {
        self.client = client
        self.rigId = rigId
        self.role = role
    }

    /// Resolves `role` to a device name via the rig, takes a full property snapshot, then starts
    /// applying live updates as they arrive and re-snapshotting every `resyncInterval` as a safety
    /// net. Safe to call again — e.g. after reconnecting — which cancels and replaces *everything*
    /// still in flight from a previous call, including one still resolving the device name or
    /// taking its initial snapshot, not just an already-running subscription/resync: without that,
    /// a second call landing before the first had gotten that far couldn't cancel anything (there
    /// was nothing yet to cancel), and whichever call's setup finished last would silently
    /// overwrite the other's `subscriptionTask`/`resyncTask` references — orphaning the other
    /// call's subscription and resync loop permanently, since `stop()` can only reach whatever the
    /// stored references currently point at.
    ///
    /// `resyncInterval` of `nil` disables the periodic safety-net resync entirely, relying purely
    /// on `messageEvents`; not recommended for anything you actually depend on staying accurate
    /// over a long session, since that stream can silently miss updates (`docs/Design.md#event-
    /// streams`) with nothing to notice on its own.
    public func start(resyncInterval: Duration? = .seconds(300)) async {
        // A second start() landing while this teardown() is still awaiting the server's
        // unsubscribe confirmation (actor reentrancy — this suspends at that await, so another
        // call can interleave here before subscribedDevice is nilled) will read the same
        // subscribedDevice and issue its own redundant unsubscribe for the same uri. Accepted:
        // unsubscribe(uri:, session:) is a documented no-op if the uri wasn't subscribed, so the
        // worst case is one wasted round-trip, not a correctness issue.
        await teardown()
        lastError = nil

        let task = Task { [weak self] in
            guard let self else { return }

            let device: String
            do {
                let rig = try await self.client.getRig(id: self.rigId)
                guard let resolvedDevice = rig.components.first(where: { $0.role == self.role })?.device else {
                    self.lastError = "No \(self.role) component with a device name on rig '\(self.rigId)'."
                    return
                }
                device = resolvedDevice
            } catch {
                if !Task.isCancelled {
                    self.lastError = String(describing: error)
                }
                return
            }
            guard !Task.isCancelled else { return }

            self.deviceName = device
            await self.refreshSnapshot(device: device)
            guard !Task.isCancelled else { return }

            self.beginSubscription(device: device)
            if let resyncInterval {
                self.beginResync(device: device, interval: resyncInterval)
            }
        }
        startTask = task
        await task.value
    }

    /// Stops the live subscription and periodic resync (and any still-in-flight `start()` call).
    /// `properties`/`deviceName` are left as they last were — this doesn't clear observed state,
    /// just stops keeping it fresh.
    ///
    /// `async`, and actually waits for the server to confirm the `messageEvents` unsubscribe,
    /// rather than just cancelling `subscriptionTask` and returning immediately: cancelling the
    /// stream's consumer *does* eventually trigger its own unsubscribe as a side effect (see
    /// `INDIMCPClient.subscribeToResourceUpdates`'s `onTermination`), but on a detached,
    /// un-awaited `Task` — a caller that calls `stop()` and then `start()` again in quick
    /// succession (e.g. `DeviceTabsView`'s `isActive`-scoped `.task(id:)`, switching away from and
    /// back to a device tab) could have its fresh subscribe race that stale unsubscribe over the
    /// wire. If the old unsubscribe lands *after* the new subscribe, the server silently drops the
    /// new subscription from its subscriber set — this instance believes it's live but never
    /// receives another event for the rest of the session, exactly the "properties stopped
    /// updating" symptom this fixes. Awaiting the unsubscribe here, before returning, guarantees
    /// it's fully resolved server-side before any subsequent `start()` call can re-subscribe.
    public func stop() async {
        await teardown()
    }

    /// Cancels every in-flight task and, if `beginSubscription` had subscribed to `messageEvents`,
    /// waits for the server to confirm it's unsubscribed before returning — see `stop()`'s doc
    /// comment for why that has to be awaited rather than left to fire-and-forget cleanup.
    private func teardown() async {
        startTask?.cancel()
        startTask = nil
        subscriptionTask?.cancel()
        subscriptionTask = nil
        resyncTask?.cancel()
        resyncTask = nil
        if let subscribedDevice {
            await client.unsubscribeFromResource(uri: INDIMCPClient.messagesURI(device: subscribedDevice))
            self.subscribedDevice = nil
        }
    }

    private func beginSubscription(device: String) {
        subscribedDevice = device
        subscriptionTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await events in self.client.messageEvents(device: device) {
                    // Newest first, per messageEvents' own convention — apply oldest-to-newest so
                    // the most recent state for a given property name is always what ends up set.
                    for event in events.reversed() {
                        self.apply(event)
                    }
                }
            } catch {
                if !Task.isCancelled {
                    self.lastError = String(describing: error)
                }
            }
        }
    }

    private func beginResync(device: String, interval: Duration) {
        resyncTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled, let self else { return }
                await self.refreshSnapshot(device: device)
            }
        }
    }

    private func refreshSnapshot(device: String) async {
        do {
            let snapshot = try await client.getDeviceProperties(device: device)
            properties = snapshot.properties
            isRefreshed = snapshot.refreshed
        } catch {
            lastError = String(describing: error)
        }
    }

    /// Applies one live event to `properties` — `internal` rather than `private` so it's directly
    /// unit-testable (`@testable import`) without needing a live server, since this is the actual
    /// state-transition logic everything else here exists to drive.
    func apply(_ event: IndiEvent) {
        guard let name = event.name else { return }
        switch event.kind {
        case "propertyDefinition", "propertyUpdate":
            properties[name] = DeviceProperty(type: event.type, state: event.state, elements: event.elements ?? [:])
        case "propertyDeleted":
            properties.removeValue(forKey: name)
        default:
            break
        }
    }
}

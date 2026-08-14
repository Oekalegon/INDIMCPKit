import Observation

/// Keeps the live `indi://messages` event stream (`messageEvents(device:)`, IMCPKIT-14) available
/// as in-memory `@Observable` state, optionally scoped to one device.
///
/// `start(device:)` is race-safe the same way `ObservableDevice.start()` is: it awaits the
/// previous subscription's `resources/unsubscribe` confirmation before issuing the next
/// `resources/subscribe`, rather than just cancelling the local consuming task and letting the
/// stream's own fire-and-forget cleanup (`INDIMCPClient.subscribeToResourceUpdates`'s
/// `onTermination`) catch up eventually. Without that, switching the scope back and forth (e.g. a
/// device picker going A → B → A within a short window) risks the *first* A subscription's
/// unsubscribe landing on the wire *after* the *second* A subscribe — the server would silently
/// drop the second subscription from its subscriber set, leaving this instance believing it's
/// live but never receiving another event for that device again, with nothing to surface the
/// failure (nothing throws; the server's `_notify` simply stops firing for a URI with no
/// subscriber). See `ObservableDevice.start()`'s own doc comment for the identical race in the
/// property-state stream this mirrors.
///
/// `@MainActor`-isolated, matching every other `@Observable` type in this kit for the same reason
/// `ObservableDevice` is: the realistic consumer is a SwiftUI view, and the live-update
/// subscription already needs actor-isolated mutable state to update safely as events arrive on
/// their own `Task`.
@MainActor
@Observable
public final class ObservableMessageStream {
    public let client: INDIMCPClient

    /// The current rolling window of recent messaging events, newest first — exactly what the
    /// server's `indi://messages` resource returns, replaced wholesale on every yield rather than
    /// appended to (see `messageEvents`'s own doc comment: each yield is "the current window",
    /// which may repeat or drop entries relative to the previous one).
    public private(set) var events: [IndiEvent] = []

    /// The most recent error from the live subscription, if any. `nil` right after a successful
    /// `start(device:)` call, cleared again on the next one.
    public private(set) var lastError: String?

    private var subscriptionTask: Task<Void, Never>?

    /// Whether `subscribedDevice` reflects an actual subscription in flight — distinct from
    /// `subscribedDevice` itself being `nil`, since `nil` is also the *unscoped* subscription's
    /// own valid device value; without this separate flag, `teardown()` couldn't tell "never
    /// started" apart from "currently subscribed unscoped."
    private var isSubscribed = false
    private var subscribedDevice: String?

    // No deinit cancelling these — same reasoning as `ObservableDevice`: `deinit` runs
    // nonisolated even for a @MainActor class and can't touch MainActor-isolated stored
    // properties. Call `stop()` explicitly before discarding an instance if the subscription
    // needs to end deterministically rather than opportunistically.

    public init(client: INDIMCPClient) {
        self.client = client
    }

    /// Subscribes to `indi://messages`, scoped to `device` if given, replacing any previous
    /// subscription. Safe to call again — including with the same `device` as a previous call,
    /// or oscillating between a small set of devices — since the previous subscription's
    /// `resources/unsubscribe` is awaited here before the new `resources/subscribe` is issued;
    /// see this type's own doc comment for why that ordering matters.
    public func start(device: String? = nil) async {
        await teardown()
        lastError = nil
        events = []
        subscribedDevice = device
        isSubscribed = true
        beginSubscription(device: device)
    }

    /// Stops the live subscription, awaiting the server's confirmed `resources/unsubscribe`
    /// before returning — see this type's own doc comment for why `stop()` followed immediately
    /// by a `start()` needs that confirmation, not just local task cancellation.
    public func stop() async {
        await teardown()
    }

    private func teardown() async {
        // A second start()/stop() landing while this teardown() is still awaiting the server's
        // unsubscribe confirmation (actor reentrancy — this suspends at that await, so another
        // call can interleave here before isSubscribed is cleared) will read the same
        // subscribedDevice and issue its own redundant unsubscribe for the same uri. Accepted,
        // matching `ObservableDevice.start()`'s identical tradeoff: unsubscribe is a documented
        // no-op if the uri wasn't subscribed, so the worst case is one wasted round-trip, not a
        // correctness issue.
        subscriptionTask?.cancel()
        subscriptionTask = nil
        if isSubscribed {
            await client.unsubscribeFromResource(uri: INDIMCPClient.messagesURI(device: subscribedDevice))
            isSubscribed = false
        }
    }

    private func beginSubscription(device: String?) {
        subscriptionTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await window in self.client.messageEvents(device: device) {
                    self.events = window
                }
            } catch {
                if !Task.isCancelled {
                    self.lastError = String(describing: error)
                }
            }
        }
    }
}

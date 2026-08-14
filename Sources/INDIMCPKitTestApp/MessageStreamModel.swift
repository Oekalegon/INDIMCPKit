import INDIMCPKit
import Observation

/// Backs `MessageStreamView` — wraps `client.messageEvents(device:)` (IMCPKIT-14), a live,
/// best-effort stream over the `indi://messages` resource, and exposes its rolling window as
/// plain `@Observable` state. Mirrors `CameraModel`/`ServerControlModel`'s split: the view binds
/// to this, it doesn't run the `AsyncThrowingStream` consumption loop itself.
@MainActor
@Observable
final class MessageStreamModel {
    private let client: INDIMCPClient
    private let rigId: String

    /// The current rolling window of recent messaging events, newest first — exactly what the
    /// server's `indi://messages` resource returns, replaced wholesale on every yield rather than
    /// appended to (see `messageEvents`'s own doc comment: each yield is "the current window",
    /// which may repeat or drop entries relative to the previous one).
    private(set) var events: [IndiEvent] = []

    /// Every `device` name this rig's components declare, sourced from `getRig` — populates the
    /// scope picker in `MessageStreamView`, matching `ServerControlModel.rigDeviceLabels`.
    private(set) var deviceOptions: [String] = []

    private(set) var lastError: String?

    private var subscriptionTask: Task<Void, Never>?

    init(client: INDIMCPClient, rigId: String) {
        self.client = client
        self.rigId = rigId
    }

    func loadDeviceOptions() async {
        do {
            let rig = try await client.getRig(id: rigId)
            deviceOptions = rig.components.compactMap(\.device).sorted()
        } catch {
            lastError = String(describing: error)
        }
    }

    /// Subscribes to `indi://messages`, scoped to `device` if given, replacing any previous
    /// subscription. Safe to call again with a different `device` (e.g. the picker's selection
    /// changed) — each call's `uri` differs from the last whenever `device` actually changed, so
    /// there's no risk of racing an old unsubscribe against a resubscribe to the *same* uri the
    /// way `ObservableDevice.start()`'s doc comment describes; this only needs to stop consuming
    /// the old stream, not wait for the server to confirm it forgot the subscription first.
    func start(device: String?) {
        subscriptionTask?.cancel()
        events = []
        lastError = nil
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

    /// Stops consuming the live stream. Cancelling the consuming `Task` ends the `for try await`
    /// loop, which triggers the stream's own `onTermination` — a fire-and-forget
    /// `resources/unsubscribe` (see `INDIMCPClient.subscribeToResourceUpdates`). That's sufficient
    /// here: unlike `ObservableDevice.stop()`, nothing after this call depends on the server
    /// having *confirmed* the unsubscribe yet, so there's no need to await it.
    func stop() {
        subscriptionTask?.cancel()
        subscriptionTask = nil
    }
}

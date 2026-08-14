import INDIMCPKit
import Observation

/// Backs `MessageStreamView` — a thin wrapper around `ObservableMessageStream` (the race-safe
/// `indi://messages` subscription lifecycle, IMCPKIT-14/IMCPKIT-19), adding only what's specific
/// to this screen: the rig's own device names, for the scope picker. Mirrors `CameraModel`
/// wrapping `ObservableDevice` — the view binds to this, it doesn't run subscription logic itself.
@MainActor
@Observable
final class MessageStreamModel {
    private let client: INDIMCPClient
    private let rigId: String

    let stream: ObservableMessageStream

    /// Every `device` name this rig's components declare, sourced from `getRig` — populates the
    /// scope picker in `MessageStreamView`, matching `ServerControlModel.rigDeviceLabels`.
    private(set) var deviceOptions: [String] = []

    private(set) var lastError: String?

    init(client: INDIMCPClient, rigId: String) {
        self.client = client
        self.rigId = rigId
        self.stream = ObservableMessageStream(client: client)
    }

    func loadDeviceOptions() async {
        do {
            let rig = try await client.getRig(id: rigId)
            deviceOptions = rig.components.compactMap(\.device).sorted()
        } catch {
            lastError = String(describing: error)
        }
    }

    func start(device: String?) async {
        await stream.start(device: device)
    }

    func stop() async {
        await stream.stop()
    }
}

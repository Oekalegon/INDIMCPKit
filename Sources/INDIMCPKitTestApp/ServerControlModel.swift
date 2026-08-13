import INDIMCPKit
import Observation

/// Backs `ServerControlView` — loads and mutates `indiserver`/messaging/driver state via the
/// server-management tool group. Kept separate from `AppModel` since this is server-wide state,
/// not tied to a connection attempt or a selected rig.
@MainActor
@Observable
final class ServerControlModel {
    private let client: INDIMCPClient

    private(set) var serverStatus: IndiServerStatus?
    private(set) var messagingStatus: MessagingStatus?
    private(set) var driverCatalog: [DriverInfo] = []
    private(set) var runningDrivers: [DriverStatus] = []

    private(set) var isLoading = false
    private(set) var isBusy = false
    private(set) var errorMessage: String?

    init(client: INDIMCPClient) {
        self.client = client
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        do {
            async let server = client.getINDIServerStatus()
            async let messaging = client.getINDIMessagingStatus()
            async let catalog = client.listINDIDriverCatalog()
            async let running = client.listRunningINDIDrivers()
            (serverStatus, messagingStatus, driverCatalog, runningDrivers) =
                try await (server, messaging, catalog, running)
        } catch {
            errorMessage = String(describing: error)
        }
        isLoading = false
    }

    func startServer() async { await perform { try await $0.startINDIServer() } }
    func stopServer() async { await perform { try await $0.stopINDIServer() } }
    func restartServer() async { await perform { try await $0.restartINDIServer() } }

    func startMessaging() async { await perform { try await $0.startINDIMessaging() } }
    func stopMessaging() async { await perform { try await $0.stopINDIMessaging() } }

    func startDriver(label: String) async { await perform { try await $0.startINDIDriver(label: label) } }
    func stopDriver(label: String) async { await perform { try await $0.stopINDIDriver(label: label) } }

    func isDriverRunning(label: String) -> Bool {
        runningDrivers.contains { $0.label == label && $0.running }
    }

    /// Runs `action`, then reloads everything — every one of the calls above changes server/driver
    /// state that the other panels depend on, so a targeted, partial refresh isn't worth the extra
    /// bookkeeping in a test app this size.
    private func perform<T>(_ action: (INDIMCPClient) async throws -> T) async {
        isBusy = true
        errorMessage = nil
        do {
            _ = try await action(client)
        } catch {
            errorMessage = String(describing: error)
        }
        isBusy = false
        await refresh()
    }
}

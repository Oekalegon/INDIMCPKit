import Foundation
import INDIMCPKit
import Observation

/// Connection state to an INDIMCP-server instance, shared by every screen in this app.
@MainActor
@Observable
final class AppModel {
    enum ConnectionStatus: Equatable {
        case disconnected
        case connecting
        case connected
        case failed(String)
    }

    var serverURLString = "http://127.0.0.1:8000/mcp"
    private(set) var connectionStatus = ConnectionStatus.disconnected
    private(set) var client: INDIMCPClient?

    /// The rig picked (or created) on `RigSelectionView`, after connecting. `nil` until then, even
    /// once `isConnected` — device screens can't show until a rig is chosen.
    var selectedRigId: String?

    var isConnected: Bool { connectionStatus == .connected }

    func connect() async {
        guard let url = URL(string: serverURLString) else {
            connectionStatus = .failed("'\(serverURLString)' isn't a valid URL.")
            return
        }
        connectionStatus = .connecting
        let newClient = INDIMCPClient(endpoint: url)
        do {
            try await newClient.connect()
            try await ensureINDIServerAndMessagingRunning(newClient)
            client = newClient
            connectionStatus = .connected
        } catch {
            connectionStatus = .failed(String(describing: error))
        }
    }

    /// Device commands go nowhere without a running `indiserver` and an active messaging stream
    /// to receive their results — start both if they're not already up. Checks status first
    /// rather than unconditionally calling `startINDIServer`/`startINDIMessaging`: both restart
    /// (and briefly interrupt) an already-running session, which would be disruptive if this app
    /// connects to a server mid-imaging-run someone else already started.
    private func ensureINDIServerAndMessagingRunning(_ client: INDIMCPClient) async throws {
        let serverStatus = try await client.getINDIServerStatus()
        if !serverStatus.running {
            _ = try await client.startINDIServer()
        }

        let messagingStatus = try await client.getINDIMessagingStatus()
        if !messagingStatus.running {
            _ = try await client.startINDIMessaging()
        }
    }

    func disconnect() async {
        await client?.disconnect()
        client = nil
        connectionStatus = .disconnected
        selectedRigId = nil
    }
}

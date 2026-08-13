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
    var rigId = ""
    private(set) var connectionStatus = ConnectionStatus.disconnected
    private(set) var client: INDIMCPClient?

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
            client = newClient
            connectionStatus = .connected
        } catch {
            connectionStatus = .failed(String(describing: error))
        }
    }

    func disconnect() async {
        await client?.disconnect()
        client = nil
        connectionStatus = .disconnected
    }
}

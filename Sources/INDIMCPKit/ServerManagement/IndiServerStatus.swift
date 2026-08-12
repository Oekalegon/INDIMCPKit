/// Whether the managed `indiserver` process is running, and on which port.
///
/// Mirrors INDIMCP-server's `IndiServerStatus` (`indi_server.py`).
public struct IndiServerStatus: Codable, Sendable, Hashable {
    public let running: Bool
    public let port: Int

    public init(running: Bool, port: Int) {
        self.running = running
        self.port = port
    }
}

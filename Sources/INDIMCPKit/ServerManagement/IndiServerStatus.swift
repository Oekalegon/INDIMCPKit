/// Whether the managed `indiserver` process is running, and on which port.
///
/// Mirrors INDIMCP-server's `IndiServerStatus` (`indi_server.py`).
public struct IndiServerStatus: Codable, Sendable, Hashable {
    /// Whether the managed `indiserver` process is currently running.
    public let running: Bool
    /// The port the `indiserver` process is (or would be) listening on.
    public let port: Int

    /// Creates a new INDI server status.
    public init(running: Bool, port: Int) {
        self.running = running
        self.port = port
    }
}

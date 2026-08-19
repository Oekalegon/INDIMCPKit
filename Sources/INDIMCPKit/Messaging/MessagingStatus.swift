/// Current state of the INDI messaging connection.
///
/// Mirrors INDIMCP-server's `MessagingStatus` (`indi_messaging.py`).
public struct MessagingStatus: Codable, Sendable, Hashable {
    /// Whether the INDI messaging stream is currently running.
    public let running: Bool
    /// The INDI server host being connected to.
    public let host: String
    /// The INDI server port being connected to.
    public let port: Int

    /// Creates a new messaging status.
    public init(running: Bool, host: String, port: Int) {
        self.running = running
        self.host = host
        self.port = port
    }
}

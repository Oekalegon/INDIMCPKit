/// Current state of the INDI messaging connection.
///
/// Mirrors INDIMCP-server's `MessagingStatus` (`indi_messaging.py`).
public struct MessagingStatus: Codable, Sendable, Hashable {
    public let running: Bool
    public let host: String
    public let port: Int

    public init(running: Bool, host: String, port: Int) {
        self.running = running
        self.host = host
        self.port = port
    }
}

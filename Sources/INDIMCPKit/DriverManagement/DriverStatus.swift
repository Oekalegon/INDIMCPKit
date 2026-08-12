/// Current run state of a single driver.
///
/// Mirrors INDIMCP-server's `DriverStatus` (`indi_driver.py`).
public struct DriverStatus: Codable, Sendable, Hashable {
    public let label: String
    public let running: Bool

    public init(label: String, running: Bool) {
        self.label = label
        self.running = running
    }
}

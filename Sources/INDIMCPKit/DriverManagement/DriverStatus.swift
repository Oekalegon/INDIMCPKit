/// Current run state of a single driver.
///
/// Mirrors INDIMCP-server's `DriverStatus` (`indi_driver.py`).
public struct DriverStatus: Codable, Sendable, Hashable {
    /// The driver's human-readable catalog label (e.g. `"CCD Simulator"`).
    public let label: String
    /// Whether the driver is currently running on the server.
    public let running: Bool

    /// Creates a new driver status.
    public init(label: String, running: Bool) {
        self.label = label
        self.running = running
    }
}

/// A driver known to the INDI driver catalog, whether or not it is running.
///
/// Mirrors INDIMCP-server's `DriverInfo` (`indi_driver.py`).
public struct DriverInfo: Codable, Sendable, Hashable {
    /// The driver's internal identifier, as used by the underlying INDI driver system.
    public let name: String
    /// The driver's human-readable catalog label (e.g. `"CCD Simulator"`).
    public let label: String
    /// The driver's version string.
    public let version: String
    /// The device family this driver belongs to (e.g. `"CCDs"`, `"Telescopes"`).
    public let family: String
    /// The name of the driver's executable binary.
    public let binary: String
    /// Whether the driver's binary is installed on the server's device.
    public let installed: Bool

    /// Creates a new driver catalog entry.
    public init(
        name: String,
        label: String,
        version: String,
        family: String,
        binary: String,
        installed: Bool
    ) {
        self.name = name
        self.label = label
        self.version = version
        self.family = family
        self.binary = binary
        self.installed = installed
    }
}

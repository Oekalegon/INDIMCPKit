/// A driver known to the INDI driver catalog, whether or not it is running.
///
/// Mirrors INDIMCP-server's `DriverInfo` (`indi_driver.py`).
public struct DriverInfo: Codable, Sendable, Hashable {
    public let name: String
    public let label: String
    public let version: String
    public let family: String
    public let binary: String
    public let installed: Bool

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

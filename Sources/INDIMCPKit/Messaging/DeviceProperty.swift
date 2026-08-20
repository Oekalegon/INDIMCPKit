/// Snapshot of one property vector on a device, as returned by `getDeviceProperties`.
///
/// Mirrors INDIMCP-server's `DeviceProperty` (`indi_messaging.py`).
public struct DeviceProperty: Codable, Sendable, Hashable {
    /// The property vector's INDI type (e.g. `"Number"`, `"Switch"`, `"Text"`), if known.
    public let type: String?
    /// The property vector's own state, distinct from any of its element values.
    public let state: PropertyState?
    /// The property's individual elements, keyed by element name.
    public let elements: [String: String]

    /// Creates a new device property snapshot.
    public init(type: String?, state: PropertyState?, elements: [String: String]) {
        self.type = type
        self.state = state
        self.elements = elements
    }
}

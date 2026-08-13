/// Snapshot of one property vector on a device, as returned by `getDeviceProperties`.
///
/// Mirrors INDIMCP-server's `DeviceProperty` (`indi_messaging.py`).
public struct DeviceProperty: Codable, Sendable, Hashable {
    public let type: String?
    public let state: PropertyState?
    public let elements: [String: String]

    public init(type: String?, state: PropertyState?, elements: [String: String]) {
        self.type = type
        self.state = state
        self.elements = elements
    }
}

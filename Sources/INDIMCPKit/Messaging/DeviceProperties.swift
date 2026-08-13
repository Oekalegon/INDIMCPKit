/// The result of `getDeviceProperties`: a device's properties plus whether they're confirmed live.
///
/// Mirrors INDIMCP-server's `DeviceProperties` (`indi_messaging.py`). `refreshed` is `true` only
/// if the server actually observed a fresh property update for the device after sending its own
/// `getProperties` request — `false` means the driver didn't respond in time and `properties`
/// fell back to whatever was cached beforehand. Still returned either way (a last-known reading
/// is usually more useful than nothing), but a caller needing certainty of a live reading must
/// check this flag rather than assume a non-empty `properties` means it got one.
public struct DeviceProperties: Codable, Sendable, Hashable {
    public let properties: [String: DeviceProperty]
    public let refreshed: Bool

    public init(properties: [String: DeviceProperty], refreshed: Bool) {
        self.properties = properties
        self.refreshed = refreshed
    }
}

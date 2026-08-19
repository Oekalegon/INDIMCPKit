/// The result of `getDeviceProperties`: a device's properties plus whether they're confirmed live.
///
/// Mirrors INDIMCP-server's `DeviceProperties` (`indi_messaging.py`). `refreshed` is `true` only
/// if the server actually observed a fresh property update for the device after sending its own
/// `getProperties` request — `false` means the driver didn't respond in time and `properties`
/// fell back to whatever was cached beforehand. Still returned either way (a last-known reading
/// is usually more useful than nothing), but a caller needing certainty of a live reading must
/// check this flag rather than assume a non-empty `properties` means it got one.
public struct DeviceProperties: Codable, Sendable, Hashable {
    /// The device's property vectors, keyed by property name.
    public let properties: [String: DeviceProperty]
    /// Whether the server observed a fresh property update for the device after requesting one —
    /// `false` means the driver didn't respond in time and `properties` is a cached reading.
    public let refreshed: Bool

    /// Creates a new device properties snapshot.
    public init(properties: [String: DeviceProperty], refreshed: Bool) {
        self.properties = properties
        self.refreshed = refreshed
    }
}

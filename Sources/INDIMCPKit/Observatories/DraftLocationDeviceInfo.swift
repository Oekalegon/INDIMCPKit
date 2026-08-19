/// A currently connected INDI device's live `GEOGRAPHIC_COORD` reading, as gathered for
/// `draftObservatory`.
///
/// Mirrors INDIMCP-server's `DraftLocationDeviceInfo` (`observatory_store.py`).
public struct DraftLocationDeviceInfo: Codable, Sendable, Hashable {
    /// The INDI device name this reading was gathered from.
    public let name: String
    /// The raw `GEOGRAPHIC_COORD` element values, keyed by element name.
    public let geographicCoord: [String: String]?
    /// The property's state at the time it was read.
    public let state: PropertyState?

    /// Creates a new draft location device info.
    public init(name: String, geographicCoord: [String: String]?, state: PropertyState?) {
        self.name = name
        self.geographicCoord = geographicCoord
        self.state = state
    }
}

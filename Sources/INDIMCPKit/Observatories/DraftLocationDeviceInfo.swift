/// A currently connected INDI device's live `GEOGRAPHIC_COORD` reading, as gathered for
/// `draftObservatory`.
///
/// Mirrors INDIMCP-server's `DraftLocationDeviceInfo` (`observatory_store.py`).
public struct DraftLocationDeviceInfo: Codable, Sendable, Hashable {
    public let name: String
    public let geographicCoord: [String: String]?
    public let state: PropertyState?

    public init(name: String, geographicCoord: [String: String]?, state: PropertyState?) {
        self.name = name
        self.geographicCoord = geographicCoord
        self.state = state
    }
}

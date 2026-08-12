/// The id/name of a loaded observatory location, without its full definition.
///
/// Mirrors INDIMCP-server's `ObservatorySummary` (`observatory_store.py`).
public struct ObservatorySummary: Codable, Sendable, Hashable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

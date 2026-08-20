/// The id/name of a loaded observatory location, without its full definition.
///
/// Mirrors INDIMCP-server's `ObservatorySummary` (`observatory_store.py`).
public struct ObservatorySummary: Codable, Sendable, Hashable {
    /// The observatory's unique identifier.
    public let id: String
    /// The observatory's human-readable name.
    public let name: String

    /// Creates a new observatory summary.
    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

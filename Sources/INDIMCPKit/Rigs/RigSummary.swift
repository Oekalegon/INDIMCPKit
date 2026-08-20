/// The id/name of a loaded rig, without its full definition.
///
/// Mirrors INDIMCP-server's `RigSummary` (`rig_store.py`).
public struct RigSummary: Codable, Sendable, Hashable {
    /// The rig's unique identifier.
    public let id: String
    /// The rig's human-readable name.
    public let name: String

    /// Creates a new rig summary.
    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

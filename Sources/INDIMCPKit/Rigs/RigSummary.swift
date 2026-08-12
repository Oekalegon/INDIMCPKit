/// The id/name of a loaded rig, without its full definition.
///
/// Mirrors INDIMCP-server's `RigSummary` (`rig_store.py`).
public struct RigSummary: Codable, Sendable, Hashable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

/// The id/name/description of a loaded script, without its full definition.
///
/// Mirrors INDIMCP-server's `ScriptSummary` (`script_store.py`).
public struct ScriptSummary: Codable, Sendable, Hashable {
    /// The script's unique identifier.
    public let id: String
    /// The script's human-readable name.
    public let name: String
    /// A human-readable description of the script, if provided.
    public let description: String?

    /// Creates a new script summary.
    public init(id: String, name: String, description: String?) {
        self.id = id
        self.name = name
        self.description = description
    }
}

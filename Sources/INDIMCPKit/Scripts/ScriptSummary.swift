/// The id/name/description of a loaded script, without its full definition.
///
/// Mirrors INDIMCP-server's `ScriptSummary` (`script_store.py`).
public struct ScriptSummary: Codable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let description: String?

    public init(id: String, name: String, description: String?) {
        self.id = id
        self.name = name
        self.description = description
    }
}

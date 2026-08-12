/// A single imaging rig definition, as declared in one `rigs/*.yaml` file on the server.
///
/// Mirrors INDIMCP-server's `Rig` (`rig_store.py`). The server itself enforces that `components`
/// have unique `id`s within a rig; this kit doesn't re-validate that client-side, since `save_rig`
/// is the authority and will reject a duplicate.
public struct Rig: Codable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let components: [Component]

    public init(id: String, name: String, components: [Component]) {
        self.id = id
        self.name = name
        self.components = components
    }
}

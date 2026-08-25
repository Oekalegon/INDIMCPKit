import MCP

extension INDIMCPClient {
    /// Lists the id/name of every configured imaging rig.
    public func listRigs() async throws -> [RigSummary] {
        try await callToolList("list_config", arguments: ["kind": .string("rig")], decoding: RigSummary.self)
    }

    /// Returns the full definition of the imaging rig identified by `id`.
    public func getRig(id: String) async throws -> Rig {
        try await configurationTool(action: "get", kind: "rig", configId: id, decoding: Rig.self)
    }

    /// Saves a rig definition, writing it to `rigs/<rig.id>.yaml` on the server and reloading it.
    ///
    /// Refuses to replace an existing rig file unless `overwrite` is set, since reusing an `id`
    /// could otherwise silently destroy a previously saved rig.
    public func saveRig(_ rig: Rig, overwrite: Bool = false) async throws -> Rig {
        try await configurationTool(
            action: "save",
            kind: "rig",
            config: try Value(rig),
            overwrite: overwrite,
            decoding: Rig.self
        )
    }
}

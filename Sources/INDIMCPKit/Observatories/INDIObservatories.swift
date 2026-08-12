import MCP

extension INDIMCPClient {
    /// Lists the id/name of every configured observatory location.
    public func listObservatories() async throws -> [ObservatorySummary] {
        try await callToolList("list_observatories", decoding: ObservatorySummary.self)
    }

    /// Returns the full definition of the observatory location identified by `id`.
    public func getObservatory(id: String) async throws -> Observatory {
        try await callTool(
            "get_observatory",
            arguments: ["observatory_id": .string(id)],
            decoding: Observatory.self
        )
    }

    /// Saves an observatory location definition, writing it to
    /// `observatories/<observatory.id>.yaml` on the server and reloading it.
    ///
    /// Refuses to replace an existing file unless `overwrite` is set, since reusing an `id`
    /// could otherwise silently destroy a previously saved location.
    public func saveObservatory(_ observatory: Observatory, overwrite: Bool = false) async throws -> Observatory {
        try await callTool(
            "save_observatory",
            arguments: ["observatory": try Value(observatory), "overwrite": .bool(overwrite)],
            decoding: Observatory.self
        )
    }

    /// Pre-fills a draft observatory location from a connected device's live `GEOGRAPHIC_COORD`.
    ///
    /// Never auto-selects or auto-saves a location. Requires messaging to be running
    /// (`startINDIMessaging`).
    public func draftObservatory() async throws -> ObservatoryDraft {
        try await callTool("draft_observatory", decoding: ObservatoryDraft.self)
    }
}

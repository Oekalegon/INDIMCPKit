import MCP

extension INDIMCPClient {
    /// Selects a filter on the rig's filter wheel by name.
    ///
    /// Reconciles the rig's configured filter names against the driver's live state before
    /// selecting (adopts the driver's names if the rig has none configured, fails if they
    /// disagree) — see `syncFilterNames`/`adoptFilterNamesFromDriver` to resolve a disagreement
    /// explicitly.
    public func selectFilter(rigId: String, filterName: String) async throws -> ScriptRunStarted {
        try await callTool(
            "select_filter",
            arguments: ["rig_id": .string(rigId), "filterName": .string(filterName)],
            decoding: ScriptRunStarted.self
        )
    }
}

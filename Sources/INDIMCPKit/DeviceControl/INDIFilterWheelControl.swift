import MCP

extension INDIMCPClient {
    /// Selects a filter on the rig's filter wheel by name.
    ///
    /// Reconciles the rig's configured filter names against the driver's live state before
    /// selecting (adopts the driver's names if the rig has none configured, fails if they
    /// disagree) — see `syncFilterNames`/`adoptFilterNamesFromDriver` to resolve a disagreement
    /// explicitly.
    ///
    /// `filter_wheel_action`'s `action` only ever takes `"select"` today — kept as an explicit
    /// discriminator (rather than a plain tool with no `action` param) so a future second
    /// filter-wheel action doesn't need another tool-surface change.
    public func selectFilter(rigId: String, filterName: String) async throws -> ScriptRunStarted {
        try await callTool(
            "filter_wheel_action",
            arguments: [
                "rig_id": .string(rigId),
                "action": .string("select"),
                "filterName": .string(filterName),
            ],
            decoding: ScriptRunStarted.self
        )
    }
}

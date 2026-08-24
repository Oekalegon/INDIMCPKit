import MCP

extension INDIMCPClient {
    /// Moves the rig's focuser to an absolute position.
    ///
    /// Checked server-side against the rig component's own `minPosition`/`maxPosition`, if
    /// declared.
    ///
    /// `focuser_action`'s `action` only ever takes `"set_position"` today — kept as an explicit
    /// discriminator (rather than a plain tool with no `action` param) so a future second
    /// focuser action doesn't need another tool-surface change.
    public func setFocusPosition(rigId: String, position: Int) async throws -> ScriptRunStarted {
        try await callTool(
            "focuser_action",
            arguments: [
                "rig_id": .string(rigId),
                "action": .string("set_position"),
                "position": .int(position),
            ],
            decoding: ScriptRunStarted.self
        )
    }
}

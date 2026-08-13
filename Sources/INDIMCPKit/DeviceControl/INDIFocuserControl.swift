import MCP

extension INDIMCPClient {
    /// Moves the rig's focuser to an absolute position.
    ///
    /// Checked server-side against the rig component's own `minPosition`/`maxPosition`, if
    /// declared.
    public func setFocusPosition(rigId: String, position: Int) async throws -> ScriptRunStarted {
        try await callTool(
            "set_focus_position",
            arguments: ["rig_id": .string(rigId), "position": .int(position)],
            decoding: ScriptRunStarted.self
        )
    }
}

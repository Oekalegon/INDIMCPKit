import MCP

extension INDIMCPClient {
    /// Connects whichever device fills `role` in rig `rigId`.
    ///
    /// Named `connectDevice` (not `connect`) to avoid colliding with `INDIMCPClient.connect()`,
    /// which establishes the MCP session itself — a wholly different, unrelated connection.
    public func connectDevice(rigId: String, role: String) async throws -> ScriptRunStarted {
        try await callTool(
            "set_connection",
            arguments: ["rig_id": .string(rigId), "role": .string(role), "connected": .bool(true)],
            decoding: ScriptRunStarted.self
        )
    }

    /// Disconnects whichever device fills `role` in rig `rigId`.
    ///
    /// Named `disconnectDevice` (not `disconnect`) to avoid colliding with
    /// `INDIMCPClient.disconnect()`, which closes the MCP session itself — a wholly different,
    /// unrelated disconnection.
    public func disconnectDevice(rigId: String, role: String) async throws -> ScriptRunStarted {
        try await callTool(
            "set_connection",
            arguments: ["rig_id": .string(rigId), "role": .string(role), "connected": .bool(false)],
            decoding: ScriptRunStarted.self
        )
    }
}

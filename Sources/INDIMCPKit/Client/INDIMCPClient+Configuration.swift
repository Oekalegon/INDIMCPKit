import MCP

extension INDIMCPClient {
    /// `configuration(action, kind, ...)`, shared by every rig/observatory/script get/save/draft
    /// call across `INDIRigs.swift`, `INDIRigReconciliation.swift` (`draftRig`),
    /// `INDIObservatories.swift`, and `INDIScripts.swift` — replaces the old dedicated
    /// `get_rig`/`get_observatory`/`get_script`, `save_rig`/`save_observatory`/`save_script`, and
    /// `draft_rig`/`draft_observatory` tools (INDIMCP-115).
    ///
    /// `configId` is only valid (and only meaningful) with `action: "get"`; `config`/`overwrite`
    /// only with `action: "save"` — the server rejects any other combination. Each call site
    /// passes only the parameters its own action actually uses, relying on this only including a
    /// key in the request when the corresponding argument is non-`nil`.
    func configurationTool<Output: Decodable & Sendable>(
        action: String,
        kind: String,
        configId: String? = nil,
        config: Value? = nil,
        overwrite: Bool? = nil,
        decoding type: Output.Type
    ) async throws -> Output {
        var arguments: [String: Value] = ["action": .string(action), "kind": .string(kind)]
        if let configId {
            arguments["config_id"] = .string(configId)
        }
        if let config {
            arguments["config"] = config
        }
        if let overwrite {
            arguments["overwrite"] = .bool(overwrite)
        }
        return try await callTool("configuration", arguments: arguments, decoding: Output.self)
    }
}

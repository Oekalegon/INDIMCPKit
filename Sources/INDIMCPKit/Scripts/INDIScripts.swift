import MCP

extension INDIMCPClient {
    /// Lists the id/name/description of every loaded script (built-in and uploaded).
    public func listScripts() async throws -> [ScriptSummary] {
        try await callToolList("list_config", arguments: ["kind": .string("script")], decoding: ScriptSummary.self)
    }

    /// Returns the full definition of the script identified by `id`.
    public func getScript(id: String) async throws -> Script {
        try await configurationTool(action: "get", kind: "script", configId: id, decoding: Script.self)
    }

    /// Uploads and saves a script, writing it to `user_scripts/<script.id>.yaml` on the server
    /// and reloading the merged library.
    ///
    /// A separate directory from the built-in scripts, so an upload can never clobber or shadow
    /// one. Only ever validates and stores declarative step data — no executable code. Rejected
    /// outright if `script` doesn't fit the rest of the library (an unresolved `run_script`
    /// reference, a mismatched argument type, a call cycle, or an id already used by a built-in
    /// script). Refuses to replace an existing uploaded script unless `overwrite` is set, since
    /// reusing an `id` could otherwise silently destroy a previously saved script.
    public func saveScript(_ script: Script, overwrite: Bool = false) async throws -> Script {
        try await configurationTool(
            action: "save",
            kind: "script",
            config: try Value(script),
            overwrite: overwrite,
            decoding: Script.self
        )
    }
}

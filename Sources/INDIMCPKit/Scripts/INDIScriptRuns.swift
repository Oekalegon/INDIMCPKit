import MCP

extension INDIMCPClient {
    /// Starts `scriptId` running against `rigId`, returning immediately with a `runId`.
    ///
    /// Scripts run long sequences against physical hardware and are meant to keep going even if
    /// the caller disconnects, so this never blocks until the script finishes — poll
    /// `getScriptStatus(runId:)` for progress and the eventual completion/failure, or use
    /// `cancelScript`/`pauseScript`/`resumeScript` to control the run.
    ///
    /// `parameters` are substituted into the script's `{{ name }}` references, typed per the
    /// script's own declared `Parameter`s (see `getScript`) — kept as a raw `[String: Value]`
    /// since the actual shape is script-specific, matching this kit's generic treatment of script
    /// content. `locationId`, if given, identifies a saved `Observatory` this run should use —
    /// currently only consumed by `capture_frame`'s celestial-context FITS headers, best-effort
    /// even when given. An unknown `locationId` fails the run the same way an unknown `rigId`
    /// does — not a thrown error from this call itself, but a `.failed` status from a later
    /// `getScriptStatus`.
    public func runScript(
        scriptId: String,
        rigId: String,
        parameters: [String: Value]? = nil,
        locationId: String? = nil
    ) async throws -> ScriptRunStarted {
        var arguments: [String: Value] = ["script_id": .string(scriptId), "rig_id": .string(rigId)]
        if let parameters {
            arguments["parameters"] = .object(parameters)
        }
        if let locationId {
            arguments["location_id"] = .string(locationId)
        }
        return try await callTool("run_script", arguments: arguments, decoding: ScriptRunStarted.self)
    }

    /// Returns the most recently known status for a run started by `runScript`.
    public func getScriptStatus(runId: String) async throws -> ScriptRunStatus {
        try await callToolUnion(
            "get_script_status",
            arguments: ["run_id": .string(runId)],
            decoding: ScriptRunStatus.self
        )
    }

    /// Cancels a run started by `runScript`, waiting for it to actually stop.
    public func cancelScript(runId: String) async throws -> ScriptRunStatus {
        try await callToolUnion(
            "cancel_script",
            arguments: ["run_id": .string(runId)],
            decoding: ScriptRunStatus.self
        )
    }

    /// Pauses a run at its next safe point — only if its script declared itself `pausable`.
    public func pauseScript(runId: String) async throws -> PauseOutcome {
        try await callToolUnion(
            "pause_script",
            arguments: ["run_id": .string(runId)],
            decoding: PauseOutcome.self
        )
    }

    /// Resumes a run previously paused with `pauseScript`.
    public func resumeScript(runId: String) async throws -> ResumeOutcome {
        try await callToolUnion(
            "resume_script",
            arguments: ["run_id": .string(runId)],
            decoding: ResumeOutcome.self
        )
    }
}

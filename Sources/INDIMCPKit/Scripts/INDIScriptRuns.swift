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

    /// `manage_script_run(run_id, action)`, shared by every method below — replaces the old
    /// dedicated `get_script_status`/`cancel_script`/`pause_script`/`resume_script` tools
    /// (INDIMCP-117).
    private func manageScriptRun<Output: Decodable & Sendable>(
        runId: String,
        action: String,
        decoding type: Output.Type
    ) async throws -> Output {
        try await callToolUnion(
            "manage_script_run",
            arguments: ["run_id": .string(runId), "action": .string(action)],
            decoding: Output.self
        )
    }

    /// Returns the most recently known status for a run started by `runScript`.
    public func getScriptStatus(runId: String) async throws -> ScriptRunStatus {
        try await manageScriptRun(runId: runId, action: "status", decoding: ScriptRunStatus.self)
    }

    /// Cancels a run started by `runScript`, waiting for it to actually stop.
    ///
    /// This can block for as long as the run's current step takes to finish — INDIMCP-server
    /// only checks for cancellation between steps, not preemptively mid-step, so cancelling
    /// during a long `capture_frame` exposure won't return until that exposure completes.
    /// Callers needing a bounded wait should race this against their own timeout, e.g. via a
    /// child `Task` cancelled after a deadline.
    public func cancelScript(runId: String) async throws -> ScriptRunStatus {
        try await manageScriptRun(runId: runId, action: "cancel", decoding: ScriptRunStatus.self)
    }

    /// Pauses a run at its next safe point — only if its script declared itself `pausable`.
    public func pauseScript(runId: String) async throws -> PauseOutcome {
        try await manageScriptRun(runId: runId, action: "pause", decoding: PauseOutcome.self)
    }

    /// Resumes a run previously paused with `pauseScript`.
    public func resumeScript(runId: String) async throws -> ResumeOutcome {
        try await manageScriptRun(runId: runId, action: "resume", decoding: ResumeOutcome.self)
    }

    /// Polls `getScriptStatus(runId:)` at `pollInterval` until it reaches a terminal status
    /// (`ScriptRunStatus.isTerminal`), or throws `INDIMCPClientError.pollingTimedOut` after
    /// `maxAttempts` polls without one.
    ///
    /// Convenience for the common "start a script, then wait for it to finish" shape — callers
    /// that need to observe intermediate progress should poll `getScriptStatus` themselves
    /// instead.
    public func waitForTerminalStatus(
        runId: String,
        pollInterval: Duration = .milliseconds(500),
        maxAttempts: Int = 120
    ) async throws -> ScriptRunStatus {
        for _ in 0..<maxAttempts {
            let status = try await getScriptStatus(runId: runId)
            if status.isTerminal {
                return status
            }
            try await Task.sleep(for: pollInterval)
        }
        throw INDIMCPClientError.pollingTimedOut(runId: runId, attempts: maxAttempts)
    }
}

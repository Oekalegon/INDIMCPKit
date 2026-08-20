/// Returned by a `pauseScript` call that succeeded.
///
/// Mirrors INDIMCP-server's `ScriptRunPaused` (`script_runs.py`), `kind == "scriptPaused"`.
public struct ScriptRunPaused: Codable, Sendable, Hashable {
    /// The id of the paused run.
    public let runId: String
    /// The id of the rig the run is executing on.
    public let rigId: String
    /// The 1-based step index the run was at when it was paused.
    public let pausedAtStep: Int

    /// Creates a new paused-run status.
    public init(runId: String, rigId: String, pausedAtStep: Int) {
        self.runId = runId
        self.rigId = rigId
        self.pausedAtStep = pausedAtStep
    }
}

/// Returned by a `resumeScript` call that succeeded.
///
/// Mirrors INDIMCP-server's `ScriptRunResumed` (`script_runs.py`), `kind == "scriptResumed"`.
public struct ScriptRunResumed: Codable, Sendable, Hashable {
    /// The id of the resumed run.
    public let runId: String
    /// The id of the rig the run is executing on.
    public let rigId: String
    /// The 1-based step index the run resumed at.
    public let resumedAtStep: Int

    /// Creates a new resumed-run status.
    public init(runId: String, rigId: String, resumedAtStep: Int) {
        self.runId = runId
        self.rigId = rigId
        self.resumedAtStep = resumedAtStep
    }
}

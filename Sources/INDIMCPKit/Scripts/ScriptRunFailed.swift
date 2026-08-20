/// An unsuccessful terminal status.
///
/// Mirrors INDIMCP-server's `ScriptRunFailed` (`script_runs.py`), `kind == "scriptFailed"`.
public struct ScriptRunFailed: Codable, Sendable, Hashable {
    /// The id of the failed run.
    public let runId: String
    /// The id of the rig the run was executing on.
    public let rigId: String
    /// The 1-based step index the run was at when it failed.
    public let failedAtStep: Int
    /// The error that caused the run to fail.
    public let error: ScriptRunError

    /// Creates a new failed-run status.
    public init(runId: String, rigId: String, failedAtStep: Int, error: ScriptRunError) {
        self.runId = runId
        self.rigId = rigId
        self.failedAtStep = failedAtStep
        self.error = error
    }
}

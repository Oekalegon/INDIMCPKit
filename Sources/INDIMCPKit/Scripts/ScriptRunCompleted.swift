/// A successful terminal status; `result` is whatever the run produced.
///
/// Mirrors INDIMCP-server's `ScriptRunCompleted` (`script_runs.py`), `kind == "scriptCompleted"`.
public struct ScriptRunCompleted: Codable, Sendable, Hashable {
    /// The id of the completed run.
    public let runId: String
    /// The id of the rig the run executed on.
    public let rigId: String
    /// When the run completed, as an ISO 8601 timestamp string.
    public let finishedAt: String
    /// What the run produced.
    public let result: ScriptResult

    /// Creates a new completed-run status.
    public init(runId: String, rigId: String, finishedAt: String, result: ScriptResult) {
        self.runId = runId
        self.rigId = rigId
        self.finishedAt = finishedAt
        self.result = result
    }
}

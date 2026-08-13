/// A successful terminal status; `result` is whatever the run produced.
///
/// Mirrors INDIMCP-server's `ScriptRunCompleted` (`script_runs.py`), `kind == "scriptCompleted"`.
public struct ScriptRunCompleted: Codable, Sendable, Hashable {
    public let runId: String
    public let rigId: String
    public let finishedAt: String
    public let result: ScriptResult

    public init(runId: String, rigId: String, finishedAt: String, result: ScriptResult) {
        self.runId = runId
        self.rigId = rigId
        self.finishedAt = finishedAt
        self.result = result
    }
}

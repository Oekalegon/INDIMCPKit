/// An unsuccessful terminal status.
///
/// Mirrors INDIMCP-server's `ScriptRunFailed` (`script_runs.py`), `kind == "scriptFailed"`.
public struct ScriptRunFailed: Codable, Sendable, Hashable {
    public let runId: String
    public let rigId: String
    public let failedAtStep: Int
    public let error: ScriptRunError

    public init(runId: String, rigId: String, failedAtStep: Int, error: ScriptRunError) {
        self.runId = runId
        self.rigId = rigId
        self.failedAtStep = failedAtStep
        self.error = error
    }
}

/// Returned by a `resumeScript` call that succeeded.
///
/// Mirrors INDIMCP-server's `ScriptRunResumed` (`script_runs.py`), `kind == "scriptResumed"`.
public struct ScriptRunResumed: Codable, Sendable, Hashable {
    public let runId: String
    public let rigId: String
    public let resumedAtStep: Int

    public init(runId: String, rigId: String, resumedAtStep: Int) {
        self.runId = runId
        self.rigId = rigId
        self.resumedAtStep = resumedAtStep
    }
}

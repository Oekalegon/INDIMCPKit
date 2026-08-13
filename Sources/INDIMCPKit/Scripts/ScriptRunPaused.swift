/// Returned by a `pauseScript` call that succeeded.
///
/// Mirrors INDIMCP-server's `ScriptRunPaused` (`script_runs.py`), `kind == "scriptPaused"`.
public struct ScriptRunPaused: Codable, Sendable, Hashable {
    public let runId: String
    public let rigId: String
    public let pausedAtStep: Int

    public init(runId: String, rigId: String, pausedAtStep: Int) {
        self.runId = runId
        self.rigId = rigId
        self.pausedAtStep = pausedAtStep
    }
}

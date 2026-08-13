/// Acknowledges a run has started; returned immediately by `runScript`.
///
/// Mirrors INDIMCP-server's `ScriptRunStarted` (`script_runs.py`), `kind == "scriptStarted"`.
/// `pausable` is the top-level script's own declared flag, fixed for the lifetime of this run.
public struct ScriptRunStarted: Codable, Sendable, Hashable {
    public let runId: String
    public let script: String
    public let rigId: String
    public let startedAt: String
    public let pausable: Bool

    public init(runId: String, script: String, rigId: String, startedAt: String, pausable: Bool) {
        self.runId = runId
        self.script = script
        self.rigId = rigId
        self.startedAt = startedAt
        self.pausable = pausable
    }
}

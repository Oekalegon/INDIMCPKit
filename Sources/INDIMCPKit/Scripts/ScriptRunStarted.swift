/// Acknowledges a run has started; returned immediately by `runScript`.
///
/// Mirrors INDIMCP-server's `ScriptRunStarted` (`script_runs.py`), `kind == "scriptStarted"`.
/// `pausable` is the top-level script's own declared flag, fixed for the lifetime of this run.
public struct ScriptRunStarted: Codable, Sendable, Hashable {
    /// The id of the newly started run.
    public let runId: String
    /// The id of the script that was started.
    public let script: String
    /// The id of the rig the run is executing on.
    public let rigId: String
    /// When the run started, as an ISO 8601 timestamp string.
    public let startedAt: String
    /// The top-level script's own declared `pausable` flag, fixed for this run's lifetime.
    public let pausable: Bool

    /// Creates a new started-run status.
    public init(runId: String, script: String, rigId: String, startedAt: String, pausable: Bool) {
        self.runId = runId
        self.script = script
        self.rigId = rigId
        self.startedAt = startedAt
        self.pausable = pausable
    }
}

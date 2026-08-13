/// Returned instead of `ScriptRunPaused`/`ScriptRunResumed` when the run can't (yet) honor a
/// `pauseScript`/`resumeScript` call.
///
/// Mirrors INDIMCP-server's `ScriptRunPauseRejected` (`script_runs.py`), `kind ==
/// "scriptPauseRejected"`. A run whose top-level script isn't `pausable`, or one that's already
/// reached a terminal state, can't be paused/resumed at all — rejected rather than silently
/// ignored or queued.
public struct ScriptRunPauseRejected: Codable, Sendable, Hashable {
    public let runId: String
    public let rigId: String
    public let reason: String

    public init(runId: String, rigId: String, reason: String) {
        self.runId = runId
        self.rigId = rigId
        self.reason = reason
    }
}

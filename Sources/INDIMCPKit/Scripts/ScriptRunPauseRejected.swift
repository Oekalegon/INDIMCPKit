/// Returned instead of `ScriptRunPaused`/`ScriptRunResumed` when the run can't (yet) honor a
/// `pauseScript`/`resumeScript` call.
///
/// Mirrors INDIMCP-server's `ScriptRunPauseRejected` (`script_runs.py`), `kind ==
/// "scriptPauseRejected"`. A run whose top-level script isn't `pausable`, or one that's already
/// reached a terminal state, can't be paused/resumed at all — rejected rather than silently
/// ignored or queued.
public struct ScriptRunPauseRejected: Codable, Sendable, Hashable {
    /// The id of the run whose pause/resume request was rejected.
    public let runId: String
    /// The id of the rig the run is executing on.
    public let rigId: String
    /// A human-readable explanation of why the request was rejected.
    public let reason: String

    /// Creates a new pause-rejected status.
    public init(runId: String, rigId: String, reason: String) {
        self.runId = runId
        self.rigId = rigId
        self.reason = reason
    }
}

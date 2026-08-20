/// The most recently reported progress for a run, fetched via `getScriptStatus`.
///
/// Mirrors INDIMCP-server's `ScriptRunProgress` (`script_runs.py`), `kind == "scriptProgress"`.
/// `role`/`device` identify the rig component the step this progress reports on is acting on —
/// `nil` for a step with no single role of its own (`run_script`, `repeat`, `if` with no
/// `condition.role`).
public struct ScriptRunProgress: Codable, Sendable, Hashable {
    /// The id of the run this progress report is for.
    public let runId: String
    /// The id of the rig the run is executing on.
    public let rigId: String

    /// Already 1-based, not a 0-based index: the server increments its internal step counter
    /// *before* running each step and reports immediately, so `step == totalSteps` means the
    /// last step is now running/just finished, not that there's one more to go. Display it
    /// as-is ("Step \(step) of \(totalSteps)") — adding 1 double-counts and can show e.g.
    /// "Step 3 of 2" on a 2-step script's final progress report.
    public let step: Int
    /// The total number of steps in the run, if known.
    public let totalSteps: Int?
    /// A human-readable description of the current step, if provided.
    public let message: String?
    /// The rig role the current step is acting on, if it has a single one of its own.
    public let role: String?
    /// The INDI device the current step is acting on, if it has a single one of its own.
    public let device: String?

    /// Creates a new script run progress report.
    public init(
        runId: String,
        rigId: String,
        step: Int,
        totalSteps: Int?,
        message: String?,
        role: String?,
        device: String?
    ) {
        self.runId = runId
        self.rigId = rigId
        self.step = step
        self.totalSteps = totalSteps
        self.message = message
        self.role = role
        self.device = device
    }
}

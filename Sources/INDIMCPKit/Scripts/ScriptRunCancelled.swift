/// The terminal status of a run stopped via `cancelScript`.
///
/// Mirrors INDIMCP-server's `ScriptRunCancelled` (`script_runs.py`), `kind == "scriptCancelled"`.
/// `warnings` is whatever non-fatal `Issue`s were collected before cancellation.
public struct ScriptRunCancelled: Codable, Sendable, Hashable {
    /// The id of the cancelled run.
    public let runId: String
    /// The id of the rig the run was executing on.
    public let rigId: String
    /// The 1-based step index the run was at when it was cancelled.
    public let cancelledAtStep: Int
    /// When the run was cancelled, as an ISO 8601 timestamp string.
    public let finishedAt: String
    /// Every non-fatal issue collected before cancellation.
    public let warnings: [Issue]

    /// Creates a new cancelled-run status.
    public init(
        runId: String,
        rigId: String,
        cancelledAtStep: Int,
        finishedAt: String,
        warnings: [Issue]
    ) {
        self.runId = runId
        self.rigId = rigId
        self.cancelledAtStep = cancelledAtStep
        self.finishedAt = finishedAt
        self.warnings = warnings
    }
}

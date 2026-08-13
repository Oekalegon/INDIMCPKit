/// The terminal status of a run stopped via `cancelScript`.
///
/// Mirrors INDIMCP-server's `ScriptRunCancelled` (`script_runs.py`), `kind == "scriptCancelled"`.
/// `warnings` is whatever non-fatal `Issue`s were collected before cancellation.
public struct ScriptRunCancelled: Codable, Sendable, Hashable {
    public let runId: String
    public let rigId: String
    public let cancelledAtStep: Int
    public let finishedAt: String
    public let warnings: [Issue]

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

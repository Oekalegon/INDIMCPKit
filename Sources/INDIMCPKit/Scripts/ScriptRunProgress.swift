/// The most recently reported progress for a run, fetched via `getScriptStatus`.
///
/// Mirrors INDIMCP-server's `ScriptRunProgress` (`script_runs.py`), `kind == "scriptProgress"`.
/// `role`/`device` identify the rig component the step this progress reports on is acting on —
/// `nil` for a step with no single role of its own (`run_script`, `repeat`, `if` with no
/// `condition.role`).
public struct ScriptRunProgress: Codable, Sendable, Hashable {
    public let runId: String
    public let rigId: String
    public let step: Int
    public let totalSteps: Int?
    public let message: String?
    public let role: String?
    public let device: String?

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

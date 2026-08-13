/// The outcome of a successfully completed script run.
///
/// Mirrors INDIMCP-server's `ScriptResult` (`script_engine.py`). `framesCaptured` counts every
/// `capture_frame` step across the whole run (including nested `run_script` calls and `repeat`
/// iterations) — not a full per-frame metadata list; query frames via the frame-management tools
/// once modeled. `warnings` is every non-fatal `Issue` reported anywhere over the whole run, in
/// order, with no deduplication.
public struct ScriptResult: Codable, Sendable, Hashable {
    public let scriptId: String
    public let stepsExecuted: Int
    public let framesCaptured: Int
    public let warnings: [Issue]

    public init(scriptId: String, stepsExecuted: Int, framesCaptured: Int, warnings: [Issue]) {
        self.scriptId = scriptId
        self.stepsExecuted = stepsExecuted
        self.framesCaptured = framesCaptured
        self.warnings = warnings
    }
}

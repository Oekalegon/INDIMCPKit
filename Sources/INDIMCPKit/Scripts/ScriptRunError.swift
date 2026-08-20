/// The error accompanying a `scriptFailed` status.
///
/// Mirrors INDIMCP-server's `ScriptRunError` (`script_runs.py`). `warnings` is every non-fatal
/// `Issue` collected before the run failed.
public struct ScriptRunError: Codable, Sendable, Hashable {
    /// A human-readable description of the failure.
    public let message: String
    /// Every non-fatal issue collected before the run failed.
    public let warnings: [Issue]

    /// Creates a new script run error.
    public init(message: String, warnings: [Issue]) {
        self.message = message
        self.warnings = warnings
    }
}

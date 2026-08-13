/// The error accompanying a `scriptFailed` status.
///
/// Mirrors INDIMCP-server's `ScriptRunError` (`script_runs.py`). `warnings` is every non-fatal
/// `Issue` collected before the run failed.
public struct ScriptRunError: Codable, Sendable, Hashable {
    public let message: String
    public let warnings: [Issue]

    public init(message: String, warnings: [Issue]) {
        self.message = message
        self.warnings = warnings
    }
}

/// How a caller should treat an `Issue`.
///
/// Mirrors INDIMCP-server's `Severity` (`issues.py`). Only `.fatal` changes control flow
/// (aborts a run) — `.info`/`.warning`/`.error` are all "collect and continue," differing only in
/// how urgently a human should look at them.
public enum Severity: String, Codable, Sendable, Hashable {
    case info = "Info"
    case warning = "Warning"
    case error = "Error"
    case fatal = "Fatal"
}

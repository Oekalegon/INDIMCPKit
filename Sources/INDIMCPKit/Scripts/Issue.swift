/// One reported condition during a script run, `kind`-tagged like every other event/status
/// envelope in this project.
///
/// Mirrors INDIMCP-server's `Issue` (`issues.py`). `code` is a short, stable, machine-readable
/// slug (e.g. `"filterConfigSynced"`) a caller can match on without parsing `message`.
/// `role`/`device` identify who this is about, if anyone in particular — `nil` when an issue
/// isn't about a single resolved role/device.
public struct Issue: Codable, Sendable, Hashable {
    public let kind: String
    public let severity: Severity
    public let code: String
    public let message: String
    public let role: String?
    public let device: String?

    public init(
        kind: String,
        severity: Severity,
        code: String,
        message: String,
        role: String? = nil,
        device: String? = nil
    ) {
        self.kind = kind
        self.severity = severity
        self.code = code
        self.message = message
        self.role = role
        self.device = device
    }
}

/// One reported condition during a script run, `kind`-tagged like every other event/status
/// envelope in this project.
///
/// Mirrors INDIMCP-server's `Issue` (`issues.py`). `code` is a short, stable, machine-readable
/// slug (e.g. `"filterConfigSynced"`) a caller can match on without parsing `message`.
/// `role`/`device` identify who this is about, if anyone in particular — `nil` when an issue
/// isn't about a single resolved role/device.
public struct Issue: Codable, Sendable, Hashable {
    /// A discriminator identifying this payload as an issue.
    public let kind: String
    /// How serious this issue is.
    public let severity: Severity
    /// A short, stable, machine-readable slug for this issue, e.g. `"filterConfigSynced"`.
    public let code: String
    /// A human-readable description of the issue.
    public let message: String
    /// The rig role this issue concerns, if it's about a single resolved role.
    public let role: String?
    /// The INDI device this issue concerns, if it's about a single resolved device.
    public let device: String?

    /// Creates a new issue.
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

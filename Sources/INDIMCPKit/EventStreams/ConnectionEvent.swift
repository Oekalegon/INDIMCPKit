/// One connection-lifecycle event, in the same `kind`-tagged envelope convention as
/// `IndiEvent`/`ScriptRunStatus` — published to `indi://mcp-server/connection` and durably
/// logged under `EventStream.connection` (INDIMCP-57).
///
/// Mirrors INDIMCP-server's `ConnectionEvent` (`event_streams.py`). Covers three kinds of
/// connection, all sharing this same shape: this server's own TCP link to `indiserver`
/// (`target == "server"`, sourced from `indipyclient`'s local `ConnectionMade`/`ConnectionLost`
/// events), the `indiserver` process itself (`target == "indiserver"`), and individual driver
/// processes (`target` is that driver's catalog label). `target` is modeled as a plain `String`
/// rather than a closed enum — like `EventRecord.device`/`runId`, `"server"`/`"indiserver"` are
/// just the two well-known values; an individual driver's label is open-ended.
public struct ConnectionEvent: Codable, Sendable, Hashable {
    /// Whether this event reports a connection being established or lost.
    public let kind: ConnectionEventKind
    /// Which connection this event is about — `"server"` (this server's own link to
    /// `indiserver`), `"indiserver"` (the `indiserver` process), or a driver's catalog label.
    public let target: String
    /// Human-readable detail about this connection change, if the server has any to give —
    /// `nil` isn't unusual, not a sign anything's missing.
    public let message: String?
    /// When this connection change happened, as an ISO 8601 timestamp string.
    public let timestamp: String

    /// Creates a connection-lifecycle event.
    ///
    /// - Parameters:
    ///   - kind: Whether this reports a connection being established or lost.
    ///   - target: Which connection this event is about.
    ///   - message: Human-readable detail, if any.
    ///   - timestamp: When this connection change happened, as an ISO 8601 timestamp string.
    public init(kind: ConnectionEventKind, target: String, message: String?, timestamp: String) {
        self.kind = kind
        self.target = target
        self.message = message
        self.timestamp = timestamp
    }
}

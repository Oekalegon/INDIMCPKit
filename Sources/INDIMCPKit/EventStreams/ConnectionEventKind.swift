/// Whether a `ConnectionEvent` reports a connection being established or lost.
///
/// Mirrors INDIMCP-server's `ConnectionEvent.kind` (`event_streams.py`) — a closed
/// `Literal["connectionMade", "connectionLost"]`, so an unrecognized value is a genuine decode
/// error, same reasoning as `FrameType`/`FilterSyncStatus`.
public enum ConnectionEventKind: String, Codable, Sendable, Hashable {
    case connectionMade
    case connectionLost
}

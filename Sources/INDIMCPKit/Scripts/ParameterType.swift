/// The declared type of a script `Parameter`.
///
/// Mirrors INDIMCP-server's `ParameterType` (`script_store.py`) — a closed `Literal` on the
/// server side, so an unrecognized value is a genuine decode error (same reasoning as
/// `FilterSyncStatus`/`FilterAdoptStatus`), not something to tolerate.
public enum ParameterType: String, Codable, Sendable, Hashable {
    case string
    case integer
    case number
    case boolean
}

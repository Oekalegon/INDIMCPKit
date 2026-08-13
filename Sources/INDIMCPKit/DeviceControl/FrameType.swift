/// The kind of calibration (or light) frame `captureFrame` requests.
///
/// Mirrors INDIMCP-server's `FrameType` (`script_store.py`) — a closed `Literal` on the server
/// side, so an unrecognized value is a genuine decode error, same reasoning as
/// `FilterSyncStatus`/`FilterAdoptStatus`/`ParameterType`.
public enum FrameType: String, Codable, Sendable, Hashable {
    case light = "Light"
    case dark = "Dark"
    case flat = "Flat"
    case bias = "Bias"
}

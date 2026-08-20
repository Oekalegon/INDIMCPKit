/// An INDI property vector's own state, distinct from any of its element values.
///
/// Mirrors INDIMCP-server's `PropertyState` (`indi_messaging.py`). The server itself tolerates
/// state strings outside its four known values (falling back to the raw string rather than
/// rejecting them), so this decodes the same way via `.other(_:)` instead of throwing.
public enum PropertyState: Sendable, Hashable {
    case idle
    case ok
    case busy
    case alert
    case other(String)

    /// Creates a property state from its raw INDI string, falling back to `.other(_:)` for any
    /// value outside the four known states.
    public init(rawValue: String) {
        switch rawValue {
        case "Idle": self = .idle
        case "Ok": self = .ok
        case "Busy": self = .busy
        case "Alert": self = .alert
        default: self = .other(rawValue)
        }
    }

    /// The raw INDI string for this state (e.g. `"Idle"`, `"Ok"`).
    public var rawValue: String {
        switch self {
        case .idle: return "Idle"
        case .ok: return "Ok"
        case .busy: return "Busy"
        case .alert: return "Alert"
        case .other(let value): return value
        }
    }
}

extension PropertyState: Codable {
    /// Decodes from the raw INDI string, tolerating any value outside the four known states via
    /// `.other(_:)` rather than throwing.
    public init(from decoder: Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
    }

    /// Encodes as the raw INDI string.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

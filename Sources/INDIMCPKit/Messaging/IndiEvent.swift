/// A single INDI protocol event, in a `kind`/`type`-tagged envelope.
///
/// Mirrors INDIMCP-server's `IndiEvent` (`indi_messaging.py`). `timestamp` is kept as the raw
/// ISO 8601 string the server sends (`datetime.isoformat()`) rather than pre-parsed into `Date`,
/// so decoding never fails on a timestamp format detail this kit didn't anticipate.
public struct IndiEvent: Codable, Sendable, Hashable {
    /// The event's envelope tag, distinguishing this event's shape from other `kind`-tagged
    /// payloads sharing the same `payload` field (e.g. `EventRecord.payload`).
    public let kind: String
    /// The specific INDI protocol message type this event represents, if known.
    public let type: String?
    /// The INDI device this event pertains to, if any.
    public let device: String?
    /// The property vector name this event pertains to, if any.
    public let name: String?
    /// The property vector's own state at the time of this event, if applicable.
    public let state: PropertyState?
    /// A human-readable message accompanying this event, if any.
    public let message: String?
    /// The property's individual elements, keyed by element name, if applicable.
    public let elements: [String: String]?
    /// When this event occurred, as the raw ISO 8601 string the server sent.
    public let timestamp: String

    /// Creates a new INDI event.
    public init(
        kind: String,
        type: String?,
        device: String?,
        name: String?,
        state: PropertyState?,
        message: String?,
        elements: [String: String]?,
        timestamp: String
    ) {
        self.kind = kind
        self.type = type
        self.device = device
        self.name = name
        self.state = state
        self.message = message
        self.elements = elements
        self.timestamp = timestamp
    }
}

/// A single INDI protocol event, in a `kind`/`type`-tagged envelope.
///
/// Mirrors INDIMCP-server's `IndiEvent` (`indi_messaging.py`). `timestamp` is kept as the raw
/// ISO 8601 string the server sends (`datetime.isoformat()`) rather than pre-parsed into `Date`,
/// so decoding never fails on a timestamp format detail this kit didn't anticipate.
public struct IndiEvent: Codable, Sendable, Hashable {
    public let kind: String
    public let type: String?
    public let device: String?
    public let name: String?
    public let state: PropertyState?
    public let message: String?
    public let elements: [String: String]?
    public let timestamp: String

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

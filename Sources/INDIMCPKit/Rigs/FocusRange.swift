/// A focuser's `(min, max)` position range, as read from its live `ABS_FOCUS_POSITION`/
/// `FOCUS_ABSOLUTE_POSITION` property.
///
/// Mirrors INDIMCP-server's `tuple[float, float]` (`indi_messaging.get_property_range`), which
/// Python's JSON serialization renders as a two-element array — decoded/encoded here via an
/// unkeyed container rather than a keyed one to match that wire shape exactly.
public struct FocusRange: Sendable, Hashable {
    public let min: Double
    public let max: Double

    public init(min: Double, max: Double) {
        self.min = min
        self.max = max
    }
}

extension FocusRange: Codable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        min = try container.decode(Double.self)
        max = try container.decode(Double.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(min)
        try container.encode(max)
    }
}

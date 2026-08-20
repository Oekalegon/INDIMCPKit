/// A focuser's `(min, max)` position range, as read from its live `ABS_FOCUS_POSITION`/
/// `FOCUS_ABSOLUTE_POSITION` property.
///
/// Mirrors INDIMCP-server's `tuple[float, float]` (`indi_messaging.get_property_range`), which
/// Python's JSON serialization renders as a two-element array — decoded/encoded here via an
/// unkeyed container rather than a keyed one to match that wire shape exactly.
public struct FocusRange: Sendable, Hashable {
    /// The minimum focuser position.
    public let min: Double
    /// The maximum focuser position.
    public let max: Double

    /// Creates a new focus range.
    public init(min: Double, max: Double) {
        self.min = min
        self.max = max
    }
}

extension FocusRange: Codable {
    /// Decodes a focus range from its two-element unkeyed `[min, max]` wire representation.
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        min = try container.decode(Double.self)
        max = try container.decode(Double.self)
    }

    /// Encodes this focus range as a two-element unkeyed `[min, max]` array.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(min)
        try container.encode(max)
    }
}

/// A rig component's role: one of the schema's known roles, or any other string.
///
/// Mirrors INDIMCP-server's `Role` (`rig_store.py`), which is deliberately a known-literal-set
/// `| str` union rather than a closed enum — a hand-authored rig YAML file is free to declare a
/// role the schema's authors haven't thought of yet, and the server doesn't reject it. Modeled
/// the same way `PropertyState` is: known roles as static members, anything else round-trips
/// through its raw string.
public struct Role: RawRepresentable, Sendable, Hashable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }

    public var description: String { rawValue }

    /// Roles this schema's authors have thought of (`KNOWN_ROLES` in `rig_store.py`).
    public static let mount = Role(rawValue: "mount")
    public static let telescope = Role(rawValue: "telescope")
    public static let guideTelescope = Role(rawValue: "guideTelescope")
    public static let camera = Role(rawValue: "camera")
    public static let guideCamera = Role(rawValue: "guideCamera")
    public static let focuser = Role(rawValue: "focuser")
    public static let filterWheel = Role(rawValue: "filterWheel")
    public static let rotator = Role(rawValue: "rotator")
    public static let powerHub = Role(rawValue: "powerHub")
    public static let observatoryControl = Role(rawValue: "observatoryControl")
    public static let flatScreen = Role(rawValue: "flatScreen")
    public static let dewHeater = Role(rawValue: "dewHeater")
}

extension Role: Codable {
    public init(from decoder: Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

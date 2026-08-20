/// A rig component's role: one of the schema's known roles, or any other string.
///
/// Mirrors INDIMCP-server's `Role` (`rig_store.py`), which is deliberately a known-literal-set
/// `| str` union rather than a closed enum — a hand-authored rig YAML file is free to declare a
/// role the schema's authors haven't thought of yet, and the server doesn't reject it. Modeled
/// the same way `PropertyState` is: known roles as static members, anything else round-trips
/// through its raw string.
public struct Role: RawRepresentable, Sendable, Hashable, ExpressibleByStringLiteral, CustomStringConvertible {
    /// The raw role string, as declared in a rig's YAML file.
    public let rawValue: String

    /// Creates a role from its raw string, whether or not it's one of the known roles.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Creates a role from a string literal.
    public init(stringLiteral value: String) {
        self.rawValue = value
    }

    /// The raw role string.
    public var description: String { rawValue }

    /// Roles this schema's authors have thought of (`KNOWN_ROLES` in `rig_store.py`).
    public static let mount = Role(rawValue: "mount")
    /// The main imaging telescope.
    public static let telescope = Role(rawValue: "telescope")
    /// The guide telescope.
    public static let guideTelescope = Role(rawValue: "guideTelescope")
    /// The main imaging camera.
    public static let camera = Role(rawValue: "camera")
    /// The guide camera.
    public static let guideCamera = Role(rawValue: "guideCamera")
    /// The focuser.
    public static let focuser = Role(rawValue: "focuser")
    /// The filter wheel.
    public static let filterWheel = Role(rawValue: "filterWheel")
    /// The field rotator.
    public static let rotator = Role(rawValue: "rotator")
    /// The power distribution hub.
    public static let powerHub = Role(rawValue: "powerHub")
    /// The observatory dome or roof control.
    public static let observatoryControl = Role(rawValue: "observatoryControl")
    /// The flat-field calibration panel.
    public static let flatScreen = Role(rawValue: "flatScreen")
    /// The dew heater.
    public static let dewHeater = Role(rawValue: "dewHeater")
}

extension Role: Codable {
    /// Decodes a role from its raw string, whether or not it's one of the known roles.
    public init(from decoder: Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
    }

    /// Encodes this role as its raw string.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

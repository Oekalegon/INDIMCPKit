/// A currently connected INDI device's live properties, as gathered for `draftRig`.
///
/// Mirrors INDIMCP-server's `DraftDeviceInfo` (`rig_store.py`).
public struct DraftDeviceInfo: Codable, Sendable, Hashable {
    /// The INDI device name this info was gathered from.
    public let name: String
    /// The device's INDI driver family (e.g. `"CCD"`, `"Telescope"`), if known.
    public let family: String?
    /// The raw `CCD_INFO` element values, keyed by element name, if this device is a camera.
    public let ccdInfo: [String: String]?
    /// Filter slot number (as a string key) to filter name, if this device is a filter wheel.
    public let filterNames: [String: String]?
    /// The focuser's position range, if this device is a focuser.
    public let focusRange: FocusRange?

    /// Creates a new draft device info.
    public init(
        name: String,
        family: String?,
        ccdInfo: [String: String]?,
        filterNames: [String: String]?,
        focusRange: FocusRange?
    ) {
        self.name = name
        self.family = family
        self.ccdInfo = ccdInfo
        self.filterNames = filterNames
        self.focusRange = focusRange
    }
}

/// A currently connected INDI device's live properties, as gathered for `draftRig`.
///
/// Mirrors INDIMCP-server's `DraftDeviceInfo` (`rig_store.py`).
public struct DraftDeviceInfo: Codable, Sendable, Hashable {
    public let name: String
    public let family: String?
    public let ccdInfo: [String: String]?
    public let filterNames: [String: String]?
    public let focusRange: FocusRange?

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

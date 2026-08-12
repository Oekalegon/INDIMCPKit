/// A candidate rig for `suggestRig`, matched against currently connected INDI devices.
///
/// Mirrors INDIMCP-server's `RigSuggestion` (`rig_store.py`). `suggestRig` never auto-selects a
/// rig; candidates are sorted best match first for the operator or client to choose from.
public struct RigSuggestion: Codable, Sendable, Hashable {
    public let kind: String
    public let rigId: String
    public let rigName: String
    public let score: Double?
    public let matched: [String]
    public let missing: [String]

    public init(
        kind: String,
        rigId: String,
        rigName: String,
        score: Double?,
        matched: [String],
        missing: [String]
    ) {
        self.kind = kind
        self.rigId = rigId
        self.rigName = rigName
        self.score = score
        self.matched = matched
        self.missing = missing
    }
}

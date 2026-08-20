/// A candidate rig for `suggestRig`, matched against currently connected INDI devices.
///
/// Mirrors INDIMCP-server's `RigSuggestion` (`rig_store.py`). `suggestRig` never auto-selects a
/// rig; candidates are sorted best match first for the operator or client to choose from.
public struct RigSuggestion: Codable, Sendable, Hashable {
    /// A discriminator identifying this payload as a rig suggestion.
    public let kind: String
    /// The id of the candidate rig.
    public let rigId: String
    /// The name of the candidate rig.
    public let rigName: String
    /// How well this rig matches the connected devices, higher is better, or `nil` if unscored.
    public let score: Double?
    /// The component ids whose INDI devices are currently connected and match this rig.
    public let matched: [String]
    /// The component ids whose INDI devices are not currently connected.
    public let missing: [String]

    /// Creates a new rig suggestion.
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

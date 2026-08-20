/// The result of `checkRig`: which of a rig's devices are currently connected.
///
/// Mirrors INDIMCP-server's `RigCheck` (`rig_store.py`). `ok == false` is a warning, not a hard
/// failure — a rig might be intentionally used without one of its devices (e.g. imaging without
/// a guide camera).
public struct RigCheck: Codable, Sendable, Hashable {
    /// A discriminator identifying this payload as a rig check.
    public let kind: String
    /// The id of the rig that was checked.
    public let rigId: String
    /// Whether every one of the rig's devices is currently connected.
    public let ok: Bool
    /// The component ids whose INDI devices are currently connected.
    public let present: [String]
    /// The component ids whose INDI devices are not currently connected.
    public let missing: [String]

    /// Creates a new rig check.
    public init(
        kind: String,
        rigId: String,
        ok: Bool,
        present: [String],
        missing: [String]
    ) {
        self.kind = kind
        self.rigId = rigId
        self.ok = ok
        self.present = present
        self.missing = missing
    }
}

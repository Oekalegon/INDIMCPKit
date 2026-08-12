/// The result of `checkRig`: which of a rig's devices are currently connected.
///
/// Mirrors INDIMCP-server's `RigCheck` (`rig_store.py`). `ok == false` is a warning, not a hard
/// failure — a rig might be intentionally used without one of its devices (e.g. imaging without
/// a guide camera).
public struct RigCheck: Codable, Sendable, Hashable {
    public let kind: String
    public let rigId: String
    public let ok: Bool
    public let present: [String]
    public let missing: [String]

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

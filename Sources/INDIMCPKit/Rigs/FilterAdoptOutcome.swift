/// The result of `adoptFilterNamesFromDriver`.
///
/// Mirrors INDIMCP-server's `FilterAdoptOutcome` (`script_engine.py`). Always either `.matched`
/// (the rig already agreed, nothing changed) or `.adopted` (the rig's `slots` were overwritten
/// with the driver's) — never a silent failure: anything that can't be safely adopted surfaces as
/// a thrown error instead.
public struct FilterAdoptOutcome: Codable, Sendable, Hashable {
    /// Whether the rig's `slots` were overwritten, or they already matched the driver's.
    public let status: FilterAdoptStatus
    /// The rig's configured filter slots, after this call.
    public let rigSlots: [Int: String]
    /// The driver's live filter slots, as read from the connected device.
    public let liveSlots: [Int: String]

    /// Creates a new filter-adopt outcome.
    public init(status: FilterAdoptStatus, rigSlots: [Int: String], liveSlots: [Int: String]) {
        self.status = status
        self.rigSlots = rigSlots
        self.liveSlots = liveSlots
    }
}

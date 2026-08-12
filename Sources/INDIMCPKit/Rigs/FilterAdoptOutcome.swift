/// The result of `adoptFilterNamesFromDriver`.
///
/// Mirrors INDIMCP-server's `FilterAdoptOutcome` (`script_engine.py`). Always either `.matched`
/// (the rig already agreed, nothing changed) or `.adopted` (the rig's `slots` were overwritten
/// with the driver's) — never a silent failure: anything that can't be safely adopted surfaces as
/// a thrown error instead.
public struct FilterAdoptOutcome: Codable, Sendable, Hashable {
    public let status: FilterAdoptStatus
    public let rigSlots: [Int: String]
    public let liveSlots: [Int: String]

    public init(status: FilterAdoptStatus, rigSlots: [Int: String], liveSlots: [Int: String]) {
        self.status = status
        self.rigSlots = rigSlots
        self.liveSlots = liveSlots
    }
}

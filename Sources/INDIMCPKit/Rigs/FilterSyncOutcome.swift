/// The result of `syncFilterNames`.
///
/// Mirrors INDIMCP-server's `FilterSyncOutcome` (`script_engine.py`). Always either `.matched`
/// (nothing to do) or `.synced` (a push happened) — never a silent failure: anything that can't
/// be safely pushed surfaces as a thrown error instead.
public struct FilterSyncOutcome: Codable, Sendable, Hashable {
    /// Whether the driver's live filter names were pushed to, or they already matched the rig's.
    public let status: FilterSyncStatus
    /// The rig's configured filter slots, the source of truth for this call.
    public let rigSlots: [Int: String]
    /// The driver's live filter slots, after this call.
    public let liveSlots: [Int: String]

    /// Creates a new filter-sync outcome.
    public init(status: FilterSyncStatus, rigSlots: [Int: String], liveSlots: [Int: String]) {
        self.status = status
        self.rigSlots = rigSlots
        self.liveSlots = liveSlots
    }
}

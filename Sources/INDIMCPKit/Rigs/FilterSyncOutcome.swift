/// The result of `syncFilterNames`.
///
/// Mirrors INDIMCP-server's `FilterSyncOutcome` (`script_engine.py`). Always either `.matched`
/// (nothing to do) or `.synced` (a push happened) — never a silent failure: anything that can't
/// be safely pushed surfaces as a thrown error instead.
public struct FilterSyncOutcome: Codable, Sendable, Hashable {
    public let status: FilterSyncStatus
    public let rigSlots: [Int: String]
    public let liveSlots: [Int: String]

    public init(status: FilterSyncStatus, rigSlots: [Int: String], liveSlots: [Int: String]) {
        self.status = status
        self.rigSlots = rigSlots
        self.liveSlots = liveSlots
    }
}

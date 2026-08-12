/// Whether `adoptFilterNamesFromDriver` overwrote the rig's `slots`, or they already agreed.
///
/// Mirrors INDIMCP-server's `FilterAdoptOutcome.status` (`script_engine.py`). Closed on the
/// server side too (a `Literal`, not a `Literal | str` union) — see `FilterSyncStatus`'s doc
/// comment for why that means an unrecognized value is treated as a decode error here too.
public enum FilterAdoptStatus: String, Codable, Sendable, Hashable {
    /// Nothing to do — the rig's configured filter names already matched the driver's.
    case matched
    /// The rig's `slots` were overwritten with the driver's live filter names.
    case adopted
}

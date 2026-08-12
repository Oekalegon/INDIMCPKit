/// Whether `syncFilterNames` had to push a change, or the rig and driver already agreed.
///
/// Mirrors INDIMCP-server's `FilterSyncOutcome.status` (`script_engine.py`). Unlike
/// `PropertyState`/`Role`, this is a closed set on the server side too (a `Literal`, not a
/// `Literal | str` union), so decoding an unrecognized value is treated as a genuine decode error
/// rather than tolerated.
public enum FilterSyncStatus: String, Codable, Sendable, Hashable {
    /// Nothing to do — the rig's configured filter names already matched the driver's.
    case matched
    /// The rig's configured filter names were pushed to the driver.
    case synced
}

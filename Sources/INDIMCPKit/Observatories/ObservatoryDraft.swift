/// A draft observatory location, pre-filled from a connected device's live `GEOGRAPHIC_COORD` by
/// `draftObservatory`.
///
/// Mirrors INDIMCP-server's `ObservatoryDraft` (`observatory_store.py`). Never auto-selects or
/// auto-saves a location: `id`/`name` have no INDI equivalent, and a stale/missing/all-zero fix
/// is flagged in `notes` — for the operator to complete and save themselves via
/// `saveObservatory`.
public struct ObservatoryDraft: Codable, Sendable, Hashable {
    public let kind: String
    public let id: String?
    public let name: String?
    public let latitudeDeg: Double?
    public let longitudeDeg: Double?
    public let elevationMeters: Double?
    public let sourceDevice: String?
    public let notes: [String]

    public init(
        kind: String,
        id: String?,
        name: String?,
        latitudeDeg: Double?,
        longitudeDeg: Double?,
        elevationMeters: Double?,
        sourceDevice: String?,
        notes: [String]
    ) {
        self.kind = kind
        self.id = id
        self.name = name
        self.latitudeDeg = latitudeDeg
        self.longitudeDeg = longitudeDeg
        self.elevationMeters = elevationMeters
        self.sourceDevice = sourceDevice
        self.notes = notes
    }
}

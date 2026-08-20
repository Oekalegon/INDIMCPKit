/// A draft observatory location, pre-filled from a connected device's live `GEOGRAPHIC_COORD` by
/// `draftObservatory`.
///
/// Mirrors INDIMCP-server's `ObservatoryDraft` (`observatory_store.py`). Never auto-selects or
/// auto-saves a location: `id`/`name` have no INDI equivalent, and a stale/missing/all-zero fix
/// is flagged in `notes` — for the operator to complete and save themselves via
/// `saveObservatory`.
public struct ObservatoryDraft: Codable, Sendable, Hashable {
    /// A discriminator identifying this payload as an observatory draft.
    public let kind: String
    /// Not populated by `draftObservatory`; left for the caller to fill in before saving.
    public let id: String?
    /// Not populated by `draftObservatory`; left for the caller to fill in before saving.
    public let name: String?
    /// The latitude read from the source device, in degrees, or `nil` if unavailable.
    public let latitudeDeg: Double?
    /// The longitude read from the source device, in degrees, or `nil` if unavailable.
    public let longitudeDeg: Double?
    /// The elevation read from the source device, in meters, or `nil` if unavailable.
    public let elevationMeters: Double?
    /// The name of the INDI device this draft was read from.
    public let sourceDevice: String?
    /// Warnings about the draft, such as a stale, missing, or all-zero fix.
    public let notes: [String]

    /// Creates a new observatory draft.
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

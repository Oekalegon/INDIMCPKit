/// A single observatory location definition, as declared in one `observatories/*.yaml` file on
/// the server.
///
/// Mirrors INDIMCP-server's `Observatory` (`observatory_store.py`, see `ObservatorySchema.md`).
/// The server enforces `latitudeDeg` in `[-90, 90]` and `longitudeDeg` in `[-180, 180]`; this kit
/// doesn't re-validate that client-side, since `saveObservatory` is the authority and will reject
/// an out-of-range value.
public struct Observatory: Codable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let latitudeDeg: Double
    public let longitudeDeg: Double
    public let elevationMeters: Double

    public init(
        id: String,
        name: String,
        latitudeDeg: Double,
        longitudeDeg: Double,
        elevationMeters: Double = 0
    ) {
        self.id = id
        self.name = name
        self.latitudeDeg = latitudeDeg
        self.longitudeDeg = longitudeDeg
        self.elevationMeters = elevationMeters
    }
}

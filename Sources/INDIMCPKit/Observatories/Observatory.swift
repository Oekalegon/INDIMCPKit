/// A single observatory location definition, as declared in one `observatories/*.yaml` file on
/// the server.
///
/// Mirrors INDIMCP-server's `Observatory` (`observatory_store.py`, see `ObservatorySchema.md`).
/// The server enforces `latitudeDeg` in `[-90, 90]` and `longitudeDeg` in `[-180, 180]`; this kit
/// doesn't re-validate that client-side, since `saveObservatory` is the authority and will reject
/// an out-of-range value.
public struct Observatory: Codable, Sendable, Hashable {
    /// The observatory's unique identifier.
    public let id: String
    /// The observatory's human-readable name.
    public let name: String
    /// The observatory's latitude in degrees, in `[-90, 90]`.
    public let latitudeDeg: Double
    /// The observatory's longitude in degrees, in `[-180, 180]`.
    public let longitudeDeg: Double
    /// The observatory's elevation above sea level, in meters.
    public let elevationMeters: Double
    /// Real horizon obstructions (trees, buildings, terrain) at this site, as points sorted by
    /// ascending `azimuthDeg`, or `nil` if no obstruction data is available.
    ///
    /// `nil` is distinct from an explicit flat/zero profile: it means the site's real horizon
    /// obstructions are unknown, not that there are none. When present, the server's
    /// visibility check interpolates linearly between points (wrapping around 0/360) and
    /// combines the result with its own minimum-altitude argument, using whichever is higher.
    public let horizonProfile: [HorizonPoint]?

    /// Creates a new observatory location.
    public init(
        id: String,
        name: String,
        latitudeDeg: Double,
        longitudeDeg: Double,
        elevationMeters: Double = 0,
        horizonProfile: [HorizonPoint]? = nil
    ) {
        self.id = id
        self.name = name
        self.latitudeDeg = latitudeDeg
        self.longitudeDeg = longitudeDeg
        self.elevationMeters = elevationMeters
        self.horizonProfile = horizonProfile
    }
}

/// One azimuth/altitude sample of an `Observatory`'s horizon-obstruction profile.
///
/// Mirrors INDIMCP-server's `HorizonPoint` (`observatory_store.py`). `altitudeDeg` is the height
/// above the geometric horizon, in degrees, that a real obstruction (a tree, a building, a hill)
/// blocks up to at that azimuth — i.e. the minimum altitude a target must clear to be observable
/// in that direction, not the obstruction's own physical height. This kit doesn't re-validate the
/// server's bounds (`azimuthDeg` in `[0, 360)`, `altitudeDeg` in `[-90, 90]`) or the
/// sorted/unique-azimuth ordering client-side, since `saveObservatory` is the authority and will
/// reject an invalid profile.
public struct HorizonPoint: Codable, Sendable, Hashable {
    /// The azimuth of this sample, in degrees, in `[0, 360)`. Follows the usual astronomical
    /// convention: 0 is North, 90 is East, measured clockwise.
    public let azimuthDeg: Double
    /// The minimum altitude, in degrees, in `[-90, 90]`, a target must clear at this azimuth to
    /// be observable.
    public let altitudeDeg: Double

    /// Creates a new horizon profile sample.
    public init(azimuthDeg: Double, altitudeDeg: Double) {
        self.azimuthDeg = azimuthDeg
        self.altitudeDeg = altitudeDeg
    }
}

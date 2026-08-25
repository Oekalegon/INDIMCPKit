/// Parses an INDI number-vector element's string value as `Int`, tolerating a driver that
/// serializes it with a trailing `.0` — INDI number properties are floats on the wire even for
/// integer pixel/binning/bit-depth values. `nil` if `string` is `nil` or isn't parseable as
/// either.
func parseINDIInt(_ string: String?) -> Int? {
    guard let string else {
        return nil
    }
    if let value = Int(string) {
        return value
    }
    if let value = Double(string) {
        return Int(value)
    }
    return nil
}

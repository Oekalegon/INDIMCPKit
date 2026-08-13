import Foundation
import MCP

/// Decodes `value` as `Output` via a JSON round-trip.
///
/// `Value` (the MCP SDK's untyped JSON representation) isn't itself `Decoder`-backed, so there's
/// no direct way to decode a `Decodable` type from one — re-encoding to `Data` and decoding that
/// is the straightforward bridge. Shared rather than duplicated per call site (`INDIMCPClient`'s
/// tool-result decoding, `EventRecord`'s `decodedMessage()`/`decodedScriptStatus()`) once a second
/// one appeared.
func decodeValue<Output: Decodable>(_ type: Output.Type, from value: Value) throws -> Output {
    let data = try JSONEncoder().encode(value)
    return try JSONDecoder().decode(Output.self, from: data)
}

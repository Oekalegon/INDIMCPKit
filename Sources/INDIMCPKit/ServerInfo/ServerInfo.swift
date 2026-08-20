/// Version and build identification for the running INDIMCP-server instance.
///
/// Mirrors INDIMCP-server's `ServerInfo` (`server_info.py`). `version` is the server's package
/// version, bumped by hand on releases — coarse, and can stay unchanged for a long stretch of
/// ongoing `develop` work between releases. `buildTimestamp` is a finer-grained, automatic
/// stand-in for a commit id: when `develop` was last merged into the running server's checkout,
/// written by CI on every merge. `nil` on a checkout CI hasn't run against yet (e.g. a fresh
/// local clone before the first merge) — not an error, just "unknown."
///
/// Compare against `alignedINDIMCPServerVersion` to detect drift between the server this kit's
/// tool definitions were last verified against and the one an app is actually talking to.
public struct ServerInfo: Codable, Sendable, Hashable {
    /// The server's package version.
    public let version: String
    /// When `develop` was last merged into the running server's checkout, or `nil` if unknown.
    public let buildTimestamp: String?

    /// Creates a new server info.
    public init(version: String, buildTimestamp: String?) {
        self.version = version
        self.buildTimestamp = buildTimestamp
    }

    /// Whether `version` exactly matches `alignedINDIMCPServerVersion` — see that constant's doc
    /// comment for what a mismatch does (and doesn't) tell you.
    public var matchesAlignedVersion: Bool {
        version == alignedINDIMCPServerVersion
    }
}

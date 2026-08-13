import MCP

/// The INDIMCP-server package version this kit's tool definitions were last verified against —
/// see `README.md`'s "Version alignment" section. Compare against a live server's own
/// `ServerInfo.version` (via `getServerInfo()`) to detect drift between the two.
///
/// This is a coarse signal: INDIMCP-server's `version` is bumped by hand on releases, so it can
/// stay unchanged for a long stretch of ongoing `develop` work — a mismatch here is a reliable
/// "this kit predates that server's most recent release," but a match doesn't guarantee the two
/// are talking about the exact same tool surface if the server has unreleased commits ahead of
/// its own last version bump. `ServerInfo.buildTimestamp` is the finer-grained signal for that,
/// with no single "aligned" value to compare it against — it's a commit-adjacent timestamp on
/// the *server's* checkout, not something this kit can pin ahead of time.
public let alignedINDIMCPServerVersion = "0.1.0"

extension INDIMCPClient {
    /// Reports the server's package version and last-merge build timestamp.
    public func getServerInfo() async throws -> ServerInfo {
        try await callTool("get_server_info", decoding: ServerInfo.self)
    }
}

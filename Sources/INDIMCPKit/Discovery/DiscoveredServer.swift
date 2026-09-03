import Foundation

/// INDIMCP-server's Bonjour/mDNS service type, matching `indi_mcp.bonjour.SERVICE_TYPE`
/// (`_indi-mcp._tcp.local.`) exactly — a custom type, since there's no existing standard one for
/// an MCP server. `ServerDiscovery` browses for this same string; kept `public` so a caller
/// wiring up its own `NWBrowser`/`NetServiceBrowser` directly (rather than going through
/// ``ServerDiscovery``) still has one place to get it from rather than hardcoding a copy.
public let indiMCPServiceType = "_indi-mcp._tcp"

/// The domain INDIMCP-server advertises in, and the only one ``ServerDiscovery`` browses —
/// Bonjour/mDNS services are always local-network, so there's no cross-domain discovery case to
/// support here.
public let indiMCPServiceDomain = "local."

/// One INDIMCP-server instance found on the local network via Bonjour/mDNS, with enough
/// information to connect to it directly.
///
/// Produced by ``ServerDiscovery`` once a browsed service has actually been resolved to a
/// reachable host/port — see that type's doc comment for why browsing and resolution are two
/// separate steps.
public struct DiscoveredServer: Identifiable, Sendable, Equatable {
    /// The Bonjour instance name (e.g. `raspberrypi._indi-mcp._tcp.local.`'s instance-name
    /// portion), which INDIMCP-server derives from the Pi's hostname (`bonjour.py`'s
    /// `start_advertising`). Used as `id` since it's what actually distinguishes two service
    /// instances on the same network — `host`/`port` alone could coincide if a resolution briefly
    /// falls back to a stale address.
    public var id: String { name }

    /// The Bonjour instance name, as advertised — see ``id``.
    public let name: String

    /// The resolved host to connect to: a literal IP address in the common case, since that's
    /// what resolving a Bonjour service's endpoint actually yields (see ``ServerDiscovery``'s
    /// resolution step), not the `.local` hostname the server advertised itself under.
    public let host: String

    /// The resolved TCP port INDIMCP-server is listening on.
    public let port: Int

    /// The MCP endpoint's HTTP path, from the service's TXT record (INDIMCP-server's
    /// `bonjour.py` sets `path`) — Bonjour/mDNS itself has no notion of an HTTP path, so the
    /// server carries it explicitly rather than every client assuming `/mcp`. Falls back to
    /// `/mcp` if the TXT record is missing this key (an older server build, or a non-INDIMCP-
    /// server instance that happens to advertise under this type).
    public let path: String

    /// INDIMCP-server's package version, from the TXT record's `version` key
    /// (`bonjour.py`'s `_server_version()`) — `nil` if the key is missing.
    public let version: String?

    public init(name: String, host: String, port: Int, path: String = "/mcp", version: String? = nil) {
        self.name = name
        self.host = host
        self.port = port
        self.path = path
        self.version = version
    }

    /// The Streamable HTTP endpoint URL to hand straight to `INDIMCPClient.init(endpoint:)`.
    ///
    /// Always `http`, never `https`: INDIMCP-server's `streamable-http` deployment is
    /// unauthenticated and plaintext by design on the local network it advertises itself on (see
    /// `docs/Deployment.md`'s hardening notes) — there's no TLS variant this could resolve to.
    ///
    /// Built from a plain string, not `URLComponents`, so an IPv6 `host` (e.g. `fe80::1`) can be
    /// bracketed explicitly — `URLComponents.host` doesn't reliably add the brackets an IPv6
    /// literal needs in a URL string on its own.
    ///
    /// `path` is percent-encoded before being embedded: unlike `host`/`port` (parsed from a
    /// resolved network address, effectively hard to get otherwise-malformed), `path` comes
    /// verbatim from a Bonjour TXT record — arbitrary text chosen by whatever device advertises
    /// itself under `indiMCPServiceType`, since Bonjour/mDNS has no authentication. Encoding it
    /// (rather than trusting it's already URL-safe) is what keeps the `preconditionFailure` below
    /// truly unreachable rather than a crash any misconfigured or hostile device on the LAN could
    /// trigger just by advertising a `path` containing a space or other unsafe character.
    public var endpoint: URL {
        let bracketedHost = host.contains(":") ? "[\(host)]" : host
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        guard let url = URL(string: "http://\(bracketedHost):\(port)\(encodedPath)") else {
            preconditionFailure(
                "DiscoveredServer(host: \(host), port: \(port), path: \(path)) failed to form a valid URL"
            )
        }
        return url
    }
}

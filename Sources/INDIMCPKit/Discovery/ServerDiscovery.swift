import Foundation
import Network
import Observation

/// Browses the local network for INDIMCP-server instances advertised via Bonjour/mDNS
/// (`indi_mcp.bonjour`, INDIMCP-140) and resolves each one to a connectable ``DiscoveredServer``.
///
/// Wraps `Network`'s `NWBrowser` rather than the older `NetServiceBrowser`/`NetService` pair —
/// this kit's platform floor (macOS 14 / iOS 17) has no reason to reach for the legacy API, and
/// `NWBrowser` avoids the separate resolve-delegate dance `NetService` needs.
///
/// Browsing and resolution are two separate steps here, not one: `NWBrowser` reports a service
/// the moment it sees it on the network, before that service's host/port are known — publishing
/// results at that point would mean ``discoveredServers`` briefly held entries with no usable
/// ``DiscoveredServer/endpoint``. Instead, each browse result is resolved (via a throwaway
/// `NWConnection`) before it's added to ``discoveredServers``, so every entry in that list is
/// already connectable.
///
/// `@MainActor`, matching every other `@Observable` type in this kit (``ObservableDevice``,
/// ``ObservableMessageStream``) — the realistic consumer is a SwiftUI view, and `NWBrowser`'s own
/// callback-based API needs a single isolation domain to publish into safely as results arrive.
@MainActor
@Observable
public final class ServerDiscovery {
    /// INDIMCP-server instances found so far, most-recently-resolved last. Cleared on every
    /// ``start()`` and updated in place as services come and go while browsing continues.
    public private(set) var discoveredServers: [DiscoveredServer] = []

    /// Whether a browse is currently running — `true` from ``start()`` until ``stop()`` or a
    /// fatal `NWBrowser` failure.
    public private(set) var isBrowsing = false

    /// The most recent browse-level failure (e.g. no multicast-capable network interface), if
    /// any. Doesn't include a single service's resolution failing — that service is just dropped
    /// silently, the same way a service that goes offline is (see `apply(changes:)`).
    public private(set) var lastError: String?

    private var browser: NWBrowser?
    /// Resolution connections currently in flight, keyed by the browsed endpoint they're
    /// resolving — kept around so ``stop()`` and a service's `.removed` change can cancel the
    /// in-flight resolution rather than let it complete into a list that no longer wants it.
    private var resolutions: [NWEndpoint: NWConnection] = [:]

    public init() {}

    /// Starts (or restarts) browsing for `_indi-mcp._tcp.local.` services, clearing any
    /// previously discovered servers first.
    public func start() {
        stop()
        lastError = nil
        let browser = NWBrowser(
            for: .bonjour(type: indiMCPServiceType, domain: indiMCPServiceDomain),
            using: .tcp
        )
        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                self?.handle(state: state)
            }
        }
        browser.browseResultsChangedHandler = { [weak self] _, changes in
            Task { @MainActor [weak self] in
                self?.apply(changes: changes)
            }
        }
        self.browser = browser
        browser.start(queue: .main)
        isBrowsing = true
    }

    /// Stops browsing and cancels every resolution still in flight. Safe to call even if
    /// browsing was never started, or already stopped.
    public func stop() {
        browser?.cancel()
        browser = nil
        for (_, connection) in resolutions {
            connection.cancel()
        }
        resolutions = [:]
        isBrowsing = false
    }

    private func handle(state: NWBrowser.State) {
        switch state {
        case .failed(let error):
            lastError = String(describing: error)
            isBrowsing = false
        case .cancelled:
            isBrowsing = false
        default:
            break
        }
    }

    private func apply(changes: Set<NWBrowser.Result.Change>) {
        for change in changes {
            switch change {
            case .added(let result), .changed(old: _, new: let result, flags: _):
                resolve(result)
            case .removed(let result):
                resolutions.removeValue(forKey: result.endpoint)?.cancel()
                discoveredServers.removeAll { $0.name == serviceName(from: result.endpoint) }
            case .identical:
                break
            @unknown default:
                break
            }
        }
    }

    /// Resolves one browsed result's endpoint to a concrete host/port via a throwaway TCP
    /// connection, then publishes it into ``discoveredServers`` once resolved — see this type's
    /// own doc comment for why resolution happens before publishing rather than after.
    private func resolve(_ result: NWBrowser.Result) {
        guard let name = serviceName(from: result.endpoint) else { return }
        resolutions.removeValue(forKey: result.endpoint)?.cancel()

        let connection = NWConnection(to: result.endpoint, using: .tcp)
        resolutions[result.endpoint] = connection
        connection.stateUpdateHandler = { [weak self] state in
            guard case .ready = state else {
                if case .failed = state {
                    Task { @MainActor [weak self] in
                        self?.resolutions.removeValue(forKey: result.endpoint)
                    }
                }
                return
            }
            let resolvedEndpoint = connection.currentPath?.remoteEndpoint
            connection.cancel()
            Task { @MainActor [weak self] in
                self?.resolutions.removeValue(forKey: result.endpoint)
                guard let self, let (host, port) = Self.hostAndPort(from: resolvedEndpoint) else { return }
                let server = DiscoveredServer(
                    name: name,
                    host: host,
                    port: port,
                    path: Self.txtValue(result.metadata, key: "path") ?? "/mcp",
                    version: Self.txtValue(result.metadata, key: "version")
                )
                self.discoveredServers.removeAll { $0.name == name }
                self.discoveredServers.append(server)
            }
        }
        connection.start(queue: .main)
    }

    private func serviceName(from endpoint: NWEndpoint) -> String? {
        guard case .service(let name, _, _, _) = endpoint else { return nil }
        return name
    }

    private static func hostAndPort(from endpoint: NWEndpoint?) -> (host: String, port: Int)? {
        guard case .hostPort(let host, let port) = endpoint else { return nil }
        let hostString: String
        switch host {
        case .ipv4(let address):
            hostString = Self.strippingZoneID(from: "\(address)")
        case .ipv6(let address):
            hostString = Self.strippingZoneID(from: "\(address)")
        case .name(let hostname, _):
            hostString = hostname
        @unknown default:
            return nil
        }
        return (hostString, Int(port.rawValue))
    }

    /// Drops a zone-id suffix (e.g. `192.168.68.80%en0`, `fe80::1%en0`) from a resolved address's
    /// description — `NWEndpoint.Host`'s `description` appends the resolving interface this way
    /// for *both* IPv4 and IPv6 addresses (confirmed against a real resolution, not just IPv6 as
    /// initially assumed), and the zone id isn't part of the address itself nor meaningful once
    /// carried into a URL handed to a different networking stack (e.g. `URLSession`).
    private static func strippingZoneID(from address: String) -> String {
        address.split(separator: "%").first.map(String.init) ?? address
    }

    private static func txtValue(_ metadata: NWBrowser.Result.Metadata, key: String) -> String? {
        guard case .bonjour(let record) = metadata else { return nil }
        return record[key]
    }
}

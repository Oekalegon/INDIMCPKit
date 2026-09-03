# Server Discovery

Find INDIMCP-server instances on the local network via Bonjour/mDNS, without the operator typing
in a hostname or IP.

## Overview

An INDIMCP-server instance running in `streamable-http`/`sse` mode advertises itself on the local
network via Bonjour/mDNS at startup (INDIMCP-140, see `indi_mcp.bonjour` on the server side). A
Raspberry Pi's IP can change between sessions on a home network, and `.local` mDNS hostnames
aren't always reliably resolvable from every client OS/network stack — discovery sidesteps both
problems by browsing for the service directly and letting `Network` resolve it.

```swift
let discovery = ServerDiscovery()
discovery.start()
// ... later, once discoveredServers has settled ...
if let server = discovery.discoveredServers.first {
    let client = INDIMCPClient(endpoint: server.endpoint)
    try await client.connect()
}
discovery.stop()
```

``ServerDiscovery`` is `@MainActor` and `@Observable`, matching ``ObservableDevice`` and
``ObservableMessageStream`` — bind ``ServerDiscovery/discoveredServers`` directly into a SwiftUI
list, and call ``ServerDiscovery/start()``/``ServerDiscovery/stop()`` from that view's
`onAppear`/`onDisappear`.

Each ``DiscoveredServer`` is only published once it has actually been resolved to a reachable
host/port — a service that's merely been seen on the network but not yet resolved doesn't appear
in ``ServerDiscovery/discoveredServers`` at all, so every entry is immediately ready to connect:

```swift
let endpoint = server.endpoint // e.g. http://192.168.1.20:8000/mcp
```

``DiscoveredServer/endpoint`` is built from ``DiscoveredServer/host``, ``DiscoveredServer/port``,
and ``DiscoveredServer/path`` — `path` comes from the service's TXT record (falling back to
`/mcp` if absent), since Bonjour/mDNS itself has no notion of an HTTP path.

The service type browsed for, ``indiMCPServiceType``, matches INDIMCP-server's own
`indi_mcp.bonjour.SERVICE_TYPE` exactly (`_indi-mcp._tcp.local.`) — a custom type, since there's
no existing standard one for an MCP server.

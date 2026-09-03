import Testing

@testable import INDIMCPKit

@Test func discoveredServerBuildsHTTPEndpointFromIPv4Host() {
    let server = DiscoveredServer(name: "raspberrypi", host: "192.168.1.20", port: 8000, path: "/mcp")
    #expect(server.endpoint.absoluteString == "http://192.168.1.20:8000/mcp")
}

@Test func discoveredServerBracketsIPv6Host() {
    let server = DiscoveredServer(name: "raspberrypi", host: "fe80::1", port: 8000, path: "/mcp")
    #expect(server.endpoint.absoluteString == "http://[fe80::1]:8000/mcp")
}

@Test func discoveredServerFallsBackToDefaultMCPPath() {
    let server = DiscoveredServer(name: "raspberrypi", host: "192.168.1.20", port: 8000)
    #expect(server.endpoint.path == "/mcp")
}

@Test func discoveredServerIdMatchesName() {
    let server = DiscoveredServer(name: "raspberrypi", host: "192.168.1.20", port: 8000)
    #expect(server.id == "raspberrypi")
}

@Test func discoveredServerPercentEncodesAnUnsafePathInsteadOfCrashing() {
    // A Bonjour TXT record's "path" comes verbatim from whatever device advertises itself under
    // `indiMCPServiceType` — unauthenticated, so not guaranteed to already be URL-safe.
    let server = DiscoveredServer(name: "rogue", host: "192.168.1.20", port: 8000, path: "/a b")
    #expect(server.endpoint.absoluteString == "http://192.168.1.20:8000/a%20b")
}

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

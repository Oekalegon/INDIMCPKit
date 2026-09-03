import Network
import Testing

@testable import INDIMCPKit

@Test func strippingZoneIDDropsInterfaceSuffixFromIPv4() {
    #expect(ServerDiscovery.strippingZoneID(from: "192.168.68.80%en0") == "192.168.68.80")
}

@Test func strippingZoneIDDropsInterfaceSuffixFromIPv6() {
    #expect(ServerDiscovery.strippingZoneID(from: "fe80::1%en0") == "fe80::1")
}

@Test func strippingZoneIDLeavesAPlainIPv4AddressUnchanged() {
    #expect(ServerDiscovery.strippingZoneID(from: "192.168.68.80") == "192.168.68.80")
}

@Test func strippingZoneIDLeavesAPlainIPv6AddressUnchanged() {
    #expect(ServerDiscovery.strippingZoneID(from: "fe80::1") == "fe80::1")
}

@Test func hostAndPortStripsZoneIDFromAResolvedIPv4Endpoint() throws {
    let address = try #require(IPv4Address("192.168.68.80%en0"))
    let endpoint = NWEndpoint.hostPort(host: .ipv4(address), port: 8000)
    let resolved = try #require(ServerDiscovery.hostAndPort(from: endpoint))
    #expect(resolved.host == "192.168.68.80")
    #expect(resolved.port == 8000)
}

@Test func hostAndPortIsNilForANonHostPortEndpoint() {
    let endpoint = NWEndpoint.service(name: "astroprojector", type: indiMCPServiceType, domain: indiMCPServiceDomain, interface: nil)
    #expect(ServerDiscovery.hostAndPort(from: endpoint) == nil)
}

@Test func hostAndPortIsNilForANilEndpoint() {
    #expect(ServerDiscovery.hostAndPort(from: nil) == nil)
}

@Test func txtValueReadsAKeyFromBonjourMetadata() {
    var record = NWTXTRecord()
    record["path"] = "/mcp"
    #expect(ServerDiscovery.txtValue(.bonjour(record), key: "path") == "/mcp")
}

@Test func txtValueIsNilForAMissingKey() {
    let record = NWTXTRecord()
    #expect(ServerDiscovery.txtValue(.bonjour(record), key: "path") == nil)
}

@Test func txtValueIsNilWhenThereIsNoBonjourMetadataAtAll() {
    #expect(ServerDiscovery.txtValue(.none, key: "path") == nil)
}

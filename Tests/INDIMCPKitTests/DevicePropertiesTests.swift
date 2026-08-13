import Foundation
import Testing

@testable import INDIMCPKit

@Test func decodesDevicePropertiesFromServerJSONShape() throws {
    let json = Data(
        #"""
        {"properties": {"CCD_COOLER": {"type": "switch", "state": "Ok", "elements": {"COOLER_ON": "On"}},
                         "CCD_TEMPERATURE": {"type": "number", "state": "Busy", "elements": {"CCD_TEMPERATURE_VALUE": "-10.0"}}},
         "refreshed": true}
        """#.utf8
    )
    let properties = try JSONDecoder().decode(DeviceProperties.self, from: json)
    #expect(properties.refreshed)
    #expect(properties.properties.count == 2)
    #expect(properties.properties["CCD_COOLER"]?.state == .ok)
    #expect(properties.properties["CCD_COOLER"]?.elements["COOLER_ON"] == "On")
    #expect(properties.properties["CCD_TEMPERATURE"]?.state == .busy)
}

@Test func decodesDevicePropertiesFallenBackToCache() throws {
    let json = Data(#"{"properties": {}, "refreshed": false}"#.utf8)
    let properties = try JSONDecoder().decode(DeviceProperties.self, from: json)
    #expect(!properties.refreshed)
    #expect(properties.properties.isEmpty)
}

@Test func decodesDevicePropertyWithNullTypeAndState() throws {
    // The server models type/state as optional — a driver's own vector can, at least in
    // principle, omit either.
    let json = Data(#"{"type": null, "state": null, "elements": {}}"#.utf8)
    let property = try JSONDecoder().decode(DeviceProperty.self, from: json)
    #expect(property.type == nil)
    #expect(property.state == nil)
    #expect(property.elements.isEmpty)
}

@Test func decodesDevicePropertyWithUnrecognizedState() throws {
    // PropertyState tolerates values outside its four known ones (see PropertyStateTests) -
    // confirm that tolerance survives being embedded inside DeviceProperty too.
    let json = Data(#"{"type": "text", "state": "SomethingNew", "elements": {}}"#.utf8)
    let property = try JSONDecoder().decode(DeviceProperty.self, from: json)
    #expect(property.state == .other("SomethingNew"))
}

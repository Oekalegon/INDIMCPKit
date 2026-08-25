import Foundation
import Testing

@testable import INDIMCPKit

@Test func decodesIntKeyedFilterSlotsFromServerJSONShape() throws {
    let json = Data(#"{"role": "filterWheel", "id": "fw1", "slots": {"1": "Ha", "2": "OIII"}}"#.utf8)
    let component = try JSONDecoder().decode(Component.self, from: json)
    #expect(component.slots == [1: "Ha", 2: "OIII"])
}

@Test func encodesIntKeyedFilterSlotsAsJSONObject() throws {
    let component = Component(role: .filterWheel, id: "fw1", slots: [1: "Ha", 2: "OIII"])
    let data = try JSONEncoder().encode(component)
    let roundTripped = try JSONDecoder().decode(Component.self, from: data)
    #expect(roundTripped == component)
}

@Test func withSlotsReplacesOnlySlotsLeavingEveryOtherFieldUnchanged() {
    let component = Component(
        role: .filterWheel,
        id: "fw1",
        make: "ZWO",
        model: "EFW",
        device: "EFW",
        slots: [1: "Ha"]
    )
    let updated = component.withSlots([1: "Ha", 2: "OIII"])

    #expect(updated.slots == [1: "Ha", 2: "OIII"])
    #expect(updated.role == component.role)
    #expect(updated.id == component.id)
    #expect(updated.make == component.make)
    #expect(updated.model == component.model)
    #expect(updated.device == component.device)
}

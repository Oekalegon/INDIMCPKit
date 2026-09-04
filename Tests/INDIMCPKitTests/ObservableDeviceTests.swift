import Foundation
import Testing

@testable import INDIMCPKit

@Suite("ObservableDevice.apply") @MainActor
struct ObservableDeviceTests {
    private func makeDevice() -> ObservableDevice {
        ObservableDevice(
            client: INDIMCPClient(endpoint: URL(string: "http://127.0.0.1:1")!),
            rigId: "rig1",
            role: .camera
        )
    }

    private func event(
        kind: String,
        name: String? = "CCD_COOLER",
        type: String? = "switch",
        state: PropertyState? = .ok,
        elements: [String: String]? = ["COOLER_ON": "On"]
    ) -> IndiEvent {
        IndiEvent(
            kind: kind, type: type, device: "CCD Simulator", name: name, state: state,
            message: nil, elements: elements, timestamp: "2026-01-01T00:00:00+00:00"
        )
    }

    @Test func propertyDefinitionAddsTheProperty() {
        let device = makeDevice()
        device.apply(event(kind: "propertyDefinition"))

        #expect(device.properties["CCD_COOLER"]?.state == .ok)
        #expect(device.properties["CCD_COOLER"]?.elements["COOLER_ON"] == "On")
    }

    @Test func propertyUpdateReplacesTheWholeProperty() {
        let device = makeDevice()
        device.apply(event(kind: "propertyDefinition", state: .busy, elements: ["COOLER_ON": "Off"]))
        device.apply(event(kind: "propertyUpdate", state: .ok, elements: ["COOLER_ON": "On"]))

        // A propertyUpdate carries the vector's full current elements (indipyclient's own event
        // data, not a partial diff) — confirm the newer event's elements entirely replace the
        // older ones rather than merging.
        #expect(device.properties["CCD_COOLER"]?.state == .ok)
        #expect(device.properties["CCD_COOLER"]?.elements == ["COOLER_ON": "On"])
    }

    @Test func propertyDeletedRemovesTheProperty() {
        let device = makeDevice()
        device.apply(event(kind: "propertyDefinition"))
        #expect(device.properties["CCD_COOLER"] != nil)

        device.apply(event(kind: "propertyDeleted", elements: nil))
        #expect(device.properties["CCD_COOLER"] == nil)
    }

    @Test func eventsWithNoNameAreIgnored() {
        let device = makeDevice()
        device.apply(event(kind: "propertyDefinition", name: nil))
        #expect(device.properties.isEmpty)
    }

    @Test func unrecognizedKindsAreIgnored() {
        let device = makeDevice()
        device.apply(event(kind: "message", name: nil, elements: nil))
        #expect(device.properties.isEmpty)
    }

    @Test func applyingOldestToNewestLeavesTheNewestStateWinning() {
        // Mirrors what start()'s subscription loop does with messageEvents' newest-first window:
        // reverse it, then apply oldest-to-newest, so the newest event for a given property is
        // always the one left standing.
        let device = makeDevice()
        let newestFirst = [
            event(kind: "propertyUpdate", state: .ok, elements: ["COOLER_ON": "On"]),
            event(kind: "propertyUpdate", state: .busy, elements: ["COOLER_ON": "Off"]),
        ]
        for event in newestFirst.reversed() {
            device.apply(event)
        }

        #expect(device.properties["CCD_COOLER"]?.state == .ok)
        #expect(device.properties["CCD_COOLER"]?.elements == ["COOLER_ON": "On"])
    }

    @Test func liveIsConnectedIsNilBeforeConnectionHasEverBeenObserved() {
        let device = makeDevice()
        #expect(device.liveIsConnected == nil)
    }

    @Test func liveIsConnectedReflectsConnectAsTrueOrFalse() {
        let device = makeDevice()
        device.apply(event(kind: "propertyDefinition", name: "CONNECTION", elements: ["CONNECT": "On"]))
        #expect(device.liveIsConnected == true)

        device.apply(event(kind: "propertyUpdate", name: "CONNECTION", elements: ["CONNECT": "Off"]))
        #expect(device.liveIsConnected == false)
    }

    @Test func liveIsConnectedGoesBackToNilOnceConnectionIsDeleted() {
        let device = makeDevice()
        device.apply(event(kind: "propertyDefinition", name: "CONNECTION", elements: ["CONNECT": "On"]))
        #expect(device.liveIsConnected == true)

        device.apply(event(kind: "propertyDeleted", name: "CONNECTION", elements: nil))
        #expect(device.liveIsConnected == nil)
    }
}

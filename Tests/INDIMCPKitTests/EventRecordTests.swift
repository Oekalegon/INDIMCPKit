import Foundation
import Testing

@testable import INDIMCPKit

@Test func decodesEventRecordFromServerJSONShape() throws {
    let json = Data(
        #"""
        {"id": 42, "stream": "scripts", "device": null, "runId": "r1",
         "occurredAt": "2026-01-01T00:00:00.000000+00:00",
         "payload": {"kind": "scriptStarted", "runId": "r1", "script": "park", "rigId": "rig1",
                     "startedAt": "2026-01-01T00:00:00+00:00", "pausable": false}}
        """#.utf8
    )
    let record = try JSONDecoder().decode(EventRecord.self, from: json)
    #expect(record.id == 42)
    #expect(record.stream == .scripts)
    #expect(record.device == nil)
    #expect(record.runId == "r1")

    let status = try record.decodedScriptStatus()
    guard case .started(let started) = status else {
        Testing.Issue.record("expected .started")
        return
    }
    #expect(started.script == "park")
}

@Test func decodesMessageEventRecordPayload() throws {
    let json = Data(
        #"""
        {"id": 1, "stream": "messages", "device": "CCD Simulator", "runId": null,
         "occurredAt": "2026-01-01T00:00:00.000000+00:00",
         "payload": {"kind": "propertyUpdate", "type": "switch", "device": "CCD Simulator",
                     "name": "CCD_COOLER", "state": "Ok", "elements": {"COOLER_ON": "On"},
                     "timestamp": "2026-01-01T00:00:00+00:00"}}
        """#.utf8
    )
    let record = try JSONDecoder().decode(EventRecord.self, from: json)
    #expect(record.stream == .messages)
    #expect(record.device == "CCD Simulator")

    let event = try record.decodedMessage()
    #expect(event.name == "CCD_COOLER")
    #expect(event.elements?["COOLER_ON"] == "On")
}

@Test func eventStreamRoundTripsThroughEncoding() throws {
    for stream in [EventStream.messages, .scripts] {
        let data = try JSONEncoder().encode(stream)
        let decoded = try JSONDecoder().decode(EventStream.self, from: data)
        #expect(decoded == stream)
    }
}

@Test func messagesURILeavesUnscopedURIAlone() {
    #expect(INDIMCPClient.messagesURI(device: nil) == "indi://messages")
}

@Test func messagesURIPercentEncodesDeviceName() {
    #expect(INDIMCPClient.messagesURI(device: "CCD Simulator") == "indi://messages/CCD%20Simulator")
    #expect(INDIMCPClient.messagesURI(device: "A/B") == "indi://messages/A%2FB")
}

@Test func messagesURIPercentEncodesNonASCIICharactersAsUTF8Bytes() {
    // Matches Python's quote(safe="") exactly — its default safe set is ASCII-only, so a non-ASCII
    // letter like "é" gets percent-encoded as its UTF-8 bytes rather than left unescaped, unlike
    // CharacterSet.alphanumerics (which is Unicode-inclusive and would leave it alone).
    #expect(INDIMCPClient.messagesURI(device: "Café Simulator") == "indi://messages/Caf%C3%A9%20Simulator")
}

@Test func scriptsURIPercentEncodesRunId() {
    #expect(INDIMCPClient.scriptsURI(runId: nil) == "indi://scripts")
    #expect(INDIMCPClient.scriptsURI(runId: "run 1") == "indi://scripts/run%201")
}

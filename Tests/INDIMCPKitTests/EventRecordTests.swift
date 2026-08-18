import Foundation
import Testing

@testable import INDIMCPKit

@Test func decodesEventRecordFromServerJSONShape() throws {
    let json = Data(
        #"""
        {"id": 42, "stream": "scripts", "device": null, "runId": "r1", "target": null,
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
    #expect(record.target == nil)

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
        {"id": 1, "stream": "messages", "device": "CCD Simulator", "runId": null, "target": null,
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

@Test func decodesConnectionEventRecordPayload() throws {
    let json = Data(
        #"""
        {"id": 3, "stream": "connection", "device": null, "runId": null, "target": "indiserver",
         "occurredAt": "2026-01-01T00:00:00.000000+00:00",
         "payload": {"kind": "connectionMade", "target": "indiserver", "message": null,
                     "timestamp": "2026-01-01T00:00:00+00:00"}}
        """#.utf8
    )
    let record = try JSONDecoder().decode(EventRecord.self, from: json)
    #expect(record.stream == .connection)
    #expect(record.target == "indiserver")

    let event = try record.decodedConnectionEvent()
    #expect(event.kind == .connectionMade)
    #expect(event.target == "indiserver")
    #expect(event.message == nil)
}

@Test func decodesEventRecordWithNoTargetKeyAtAll() throws {
    // A server instance that hasn't been redeployed past INDIMCP-57 yet sends a response with
    // no "target" key at all, not an explicit null — target being Optional means the
    // synthesized decode already tolerates that (decodeIfPresent), same as every other
    // Optional field here; this just documents and locks in that behavior.
    let json = Data(
        #"""
        {"id": 1, "stream": "messages", "device": "CCD Simulator", "runId": null,
         "occurredAt": "2026-01-01T00:00:00.000000+00:00",
         "payload": {"kind": "propertyUpdate", "type": "switch", "device": "CCD Simulator",
                     "name": "CCD_COOLER", "state": "Ok", "elements": {}, "timestamp": "t"}}
        """#.utf8
    )
    let record = try JSONDecoder().decode(EventRecord.self, from: json)
    #expect(record.target == nil)
}

@Test func eventStreamRoundTripsThroughEncoding() throws {
    for stream in [EventStream.messages, .scripts, .connection] {
        let data = try JSONEncoder().encode(stream)
        let decoded = try JSONDecoder().decode(EventStream.self, from: data)
        #expect(decoded == stream)
    }
}

@Test func connectionEventKindRoundTripsThroughEncoding() throws {
    for kind in [ConnectionEventKind.connectionMade, .connectionLost] {
        let data = try JSONEncoder().encode(kind)
        let decoded = try JSONDecoder().decode(ConnectionEventKind.self, from: data)
        #expect(decoded == kind)
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
    // Renamed server-side from the top-level indi://scripts by INDIMCP-57.
    #expect(INDIMCPClient.scriptsURI(runId: nil) == "indi://mcp-server/scripts")
    #expect(INDIMCPClient.scriptsURI(runId: "run 1") == "indi://mcp-server/scripts/run%201")
}

@Test func connectionURIPercentEncodesTarget() {
    #expect(INDIMCPClient.connectionURI(target: nil) == "indi://mcp-server/connection")
    #expect(INDIMCPClient.connectionURI(target: "indiserver") == "indi://mcp-server/connection/indiserver")
    #expect(INDIMCPClient.connectionURI(target: "CCD Simulator") == "indi://mcp-server/connection/CCD%20Simulator")
}

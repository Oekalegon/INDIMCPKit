import Foundation
import Testing

@testable import INDIMCPKit

@Test func decodesScriptStartedStatus() throws {
    let json = Data(
        #"""
        {"kind": "scriptStarted", "runId": "r1", "script": "park", "rigId": "rig1",
         "startedAt": "2026-01-01T00:00:00+00:00", "pausable": false}
        """#.utf8
    )
    let status = try JSONDecoder().decode(ScriptRunStatus.self, from: json)
    guard case .started(let started) = status else {
        Testing.Issue.record("expected .started")
        return
    }
    #expect(started.runId == "r1")
    #expect(started.script == "park")
}

@Test func decodesScriptFailedStatus() throws {
    let json = Data(
        #"""
        {"kind": "scriptFailed", "runId": "r1", "rigId": "rig1", "failedAtStep": 0,
         "error": {"message": "boom", "warnings": []}}
        """#.utf8
    )
    let status = try JSONDecoder().decode(ScriptRunStatus.self, from: json)
    guard case .failed(let failed) = status else {
        Testing.Issue.record("expected .failed")
        return
    }
    #expect(failed.error.message == "boom")
}

@Test func decodesScriptPauseRejectedStatus() throws {
    let json = Data(#"{"kind": "scriptPauseRejected", "runId": "r1", "rigId": "rig1", "reason": "not pausable"}"#.utf8)
    let status = try JSONDecoder().decode(ScriptRunStatus.self, from: json)
    guard case .pauseRejected(let rejected) = status else {
        Testing.Issue.record("expected .pauseRejected")
        return
    }
    #expect(rejected.reason == "not pausable")
}

@Test func unrecognizedKindFailsToDecode() {
    let json = Data(#"{"kind": "somethingNew", "runId": "r1"}"#.utf8)
    #expect(throws: (any Error).self) {
        try JSONDecoder().decode(ScriptRunStatus.self, from: json)
    }
}

@Test func scriptRunStatusRoundTripsThroughEncoding() throws {
    let status = ScriptRunStatus.paused(ScriptRunPaused(runId: "r1", rigId: "rig1", pausedAtStep: 2))
    let data = try JSONEncoder().encode(status)
    let decoded = try JSONDecoder().decode(ScriptRunStatus.self, from: data)
    #expect(decoded == status)
}

@Test func decodesPauseOutcome() throws {
    let paused = Data(#"{"kind": "scriptPaused", "runId": "r1", "rigId": "rig1", "pausedAtStep": 1}"#.utf8)
    guard case .paused = try JSONDecoder().decode(PauseOutcome.self, from: paused) else {
        Testing.Issue.record("expected .paused")
        return
    }

    let rejected = Data(#"{"kind": "scriptPauseRejected", "runId": "r1", "rigId": "rig1", "reason": "done"}"#.utf8)
    guard case .rejected = try JSONDecoder().decode(PauseOutcome.self, from: rejected) else {
        Testing.Issue.record("expected .rejected")
        return
    }
}

@Test func decodesResumeOutcome() throws {
    let resumed = Data(#"{"kind": "scriptResumed", "runId": "r1", "rigId": "rig1", "resumedAtStep": 1}"#.utf8)
    guard case .resumed = try JSONDecoder().decode(ResumeOutcome.self, from: resumed) else {
        Testing.Issue.record("expected .resumed")
        return
    }
}

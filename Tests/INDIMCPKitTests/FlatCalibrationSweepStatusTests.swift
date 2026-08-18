import Foundation
import Testing

@testable import INDIMCPKit

@Test func decodesFlatCalibrationSweepStartedStatus() throws {
    let json = Data(
        #"""
        {"kind": "flatCalibrationSweepStarted", "sweepId": "s1", "rigId": "rig1",
         "totalCombinations": 6, "startedAt": "2026-01-01T00:00:00+00:00"}
        """#.utf8
    )
    let status = try JSONDecoder().decode(FlatCalibrationSweepStatus.self, from: json)
    guard case .started(let started) = status else {
        Testing.Issue.record("expected .started")
        return
    }
    #expect(started.sweepId == "s1")
    #expect(started.totalCombinations == 6)
}

@Test func decodesFlatCalibrationSweepProgressStatusWithCombinationResults() throws {
    let json = Data(
        #"""
        {"kind": "flatCalibrationSweepProgress", "sweepId": "s1", "rigId": "rig1",
         "combinationsCompleted": 1, "totalCombinations": 2, "currentRunId": "s1",
         "results": [{"gain": 1.0, "offset": 10.0, "exposureSeconds": 2.5, "runId": "s1",
                       "status": {"kind": "scriptCompleted", "runId": "s1", "rigId": "rig1",
                                  "finishedAt": "t", "result": {"scriptId": "capture_flat_sequence",
                                  "stepsExecuted": 3, "framesCaptured": 5, "warnings": []}}}]}
        """#.utf8
    )
    let status = try JSONDecoder().decode(FlatCalibrationSweepStatus.self, from: json)
    guard case .progress(let progress) = status else {
        Testing.Issue.record("expected .progress")
        return
    }
    #expect(progress.currentRunId == "s1")
    #expect(progress.results.count == 1)
    #expect(progress.results[0].gain == 1.0)
    guard case .completed = progress.results[0].status else {
        Testing.Issue.record("expected the nested combination result's status to be .completed")
        return
    }
}

@Test func decodesFlatCalibrationSweepFailedStatus() throws {
    let json = Data(
        #"""
        {"kind": "flatCalibrationSweepFailed", "sweepId": "s1", "rigId": "rig1",
         "failedAtCombination": 1, "message": "boom", "results": []}
        """#.utf8
    )
    let status = try JSONDecoder().decode(FlatCalibrationSweepStatus.self, from: json)
    guard case .failed(let failed) = status else {
        Testing.Issue.record("expected .failed")
        return
    }
    #expect(failed.message == "boom")
    #expect(failed.failedAtCombination == 1)
}

@Test func unrecognizedFlatSweepKindFailsToDecode() {
    let json = Data(#"{"kind": "somethingNew", "sweepId": "s1"}"#.utf8)
    #expect(throws: (any Error).self) {
        try JSONDecoder().decode(FlatCalibrationSweepStatus.self, from: json)
    }
}

@Test func flatCalibrationSweepStatusRoundTripsThroughEncoding() throws {
    let status = FlatCalibrationSweepStatus.cancelled(
        FlatCalibrationSweepCancelled(
            sweepId: "s1", rigId: "rig1", cancelledAtCombination: 2, finishedAt: "t", results: []
        )
    )
    let data = try JSONEncoder().encode(status)
    let decoded = try JSONDecoder().decode(FlatCalibrationSweepStatus.self, from: data)
    #expect(decoded == status)
}

@Test func flatSweepIsTerminalReflectsEachStatusCorrectly() {
    let nonTerminal: [FlatCalibrationSweepStatus] = [
        .started(FlatCalibrationSweepStarted(sweepId: "s1", rigId: "rig1", totalCombinations: 4, startedAt: "t")),
        .progress(
            FlatCalibrationSweepProgress(
                sweepId: "s1", rigId: "rig1", combinationsCompleted: 1, totalCombinations: 4,
                currentRunId: "s1", results: []
            )
        ),
    ]
    for status in nonTerminal {
        #expect(!status.isTerminal, "expected \(status) to not be terminal")
    }

    let terminal: [FlatCalibrationSweepStatus] = [
        .completed(FlatCalibrationSweepCompleted(sweepId: "s1", rigId: "rig1", finishedAt: "t", results: [])),
        .failed(
            FlatCalibrationSweepFailed(
                sweepId: "s1", rigId: "rig1", failedAtCombination: 0, message: "boom", results: []
            )
        ),
        .cancelled(
            FlatCalibrationSweepCancelled(
                sweepId: "s1", rigId: "rig1", cancelledAtCombination: 0, finishedAt: "t", results: []
            )
        ),
    ]
    for status in terminal {
        #expect(status.isTerminal, "expected \(status) to be terminal")
    }
}

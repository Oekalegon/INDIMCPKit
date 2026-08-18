import Foundation
import Testing

@testable import INDIMCPKit

/// Exercises `getEvents` (durable event-log catch-up) and `messageEvents`/`scriptEvents`/
/// `connectionEvents` (live
/// `resources/subscribe`-backed streams) against a real, running INDIMCP-server.
///
/// Skipped unless `INDIMCP_TEST_SERVER_URL` is set — see `INDIServerManagementIntegrationTests`
/// for how to run this manually.
@Suite("INDI event streams (live server)")
struct INDIEventStreamsIntegrationTests {
    @Test(
        "getEvents catches up on a script run's events from the durable event log",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func getEventsCatchesUpOnScriptRun() async throws {
        try await IndiServerTestLock.withLock {
            let client = try await connectedTestClient()
            _ = try await client.startINDIServer()
            _ = try await client.startINDIMessaging()

            let rig = Rig(
                id: "indimcpkit-test-\(UUID().uuidString)",
                name: "Event Log Test Rig",
                components: [Component(role: .mount, id: "mnt1", device: "Not Connected Mount")]
            )
            _ = try await client.saveRig(rig)

            let started = try await client.runScript(scriptId: "park", rigId: rig.id)
            _ = try await client.waitForTerminalStatus(
                runId: started.runId, pollInterval: .milliseconds(100), maxAttempts: 20
            )

            let records = try await client.getEvents(stream: .scripts, runId: started.runId)
            #expect(!records.isEmpty)
            #expect(records.allSatisfy { $0.stream == .scripts && $0.runId == started.runId })

            let sawStarted = try records.contains { try $0.decodedScriptStatus().isStarted(for: started.runId) }
            #expect(sawStarted)

            _ = try await client.stopINDIServer()
            await client.disconnect()
        }
    }

    @Test(
        "getEvents since filters out events before the given timestamp",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func getEventsSinceFiltersOlderEvents() async throws {
        try await IndiServerTestLock.withLock {
            let client = try await connectedTestClient()
            _ = try await client.startINDIServer()
            _ = try await client.startINDIMessaging()

            let rig = Rig(
                id: "indimcpkit-test-\(UUID().uuidString)",
                name: "Event Log Since Filter Test Rig",
                components: [Component(role: .mount, id: "mnt1", device: "Not Connected Mount")]
            )
            _ = try await client.saveRig(rig)

            let started = try await client.runScript(scriptId: "park", rigId: rig.id)
            _ = try await client.waitForTerminalStatus(
                runId: started.runId, pollInterval: .milliseconds(100), maxAttempts: 20
            )

            let allRecords = try await client.getEvents(stream: .scripts, runId: started.runId)
            let lastOccurredAt = try #require(allRecords.last).occurredAt

            // Inclusive filter: the record at exactly `since` should still come back.
            let sinceLast = try await client.getEvents(
                stream: .scripts, runId: started.runId, since: lastOccurredAt
            )
            #expect(sinceLast.contains { $0.occurredAt == lastOccurredAt })

            _ = try await client.stopINDIServer()
            await client.disconnect()
        }
    }

    @Test(
        "scriptEvents yields the run's events, scoped to that runId",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func scriptEventsStreamsLiveUpdates() async throws {
        try await IndiServerTestLock.withLock {
            let client = try await connectedTestClient()
            _ = try await client.startINDIServer()
            _ = try await client.startINDIMessaging()

            let rig = Rig(
                id: "indimcpkit-test-\(UUID().uuidString)",
                name: "Live Script Events Test Rig",
                components: [Component(role: .mount, id: "mnt1", device: "Not Connected Mount")]
            )
            _ = try await client.saveRig(rig)

            let started = try await client.runScript(scriptId: "park", rigId: rig.id)

            let sawRunEvent = try await withThrowingTaskGroup(of: Bool.self) { group in
                group.addTask {
                    for try await events in client.scriptEvents(runId: started.runId) {
                        if events.contains(where: { $0.isStarted(for: started.runId) || $0.isTerminal }) {
                            return true
                        }
                    }
                    return false
                }
                group.addTask {
                    try await Task.sleep(for: .seconds(10))
                    return false
                }
                let result = try await group.next() ?? false
                group.cancelAll()
                return result
            }

            #expect(sawRunEvent)

            _ = try await client.stopINDIServer()
            await client.disconnect()
        }
    }

    @Test(
        "getEvents catches up on indiserver's connectionMade event, filtered by target",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func getEventsCatchesUpOnConnectionEvent() async throws {
        try await IndiServerTestLock.withLock {
            let client = try await connectedTestClient()

            // startINDIServer publishes a connectionMade event for target "indiserver" once the
            // process is confirmed running (INDIMCP-57) — see indi_server.py's own
            // _connection_event helper.
            _ = try await client.startINDIServer()

            let records = try await client.getEvents(stream: .connection, target: "indiserver")
            #expect(!records.isEmpty)
            #expect(records.allSatisfy { $0.stream == .connection && $0.target == "indiserver" })

            let sawConnectionMade = try records.contains {
                try $0.decodedConnectionEvent().kind == .connectionMade
            }
            #expect(sawConnectionMade)

            _ = try await client.stopINDIServer()
            await client.disconnect()
        }
    }

    @Test(
        "connectionEvents yields indiserver's connectionMade event, scoped to that target",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func connectionEventsStreamsLiveUpdates() async throws {
        try await IndiServerTestLock.withLock {
            let client = try await connectedTestClient()

            let sawConnectionMade = try await withThrowingTaskGroup(of: Bool.self) { group in
                group.addTask {
                    for try await events in client.connectionEvents(target: "indiserver") {
                        if events.contains(where: { $0.kind == .connectionMade }) {
                            return true
                        }
                    }
                    return false
                }
                group.addTask {
                    // Give the subscription above a moment to actually register before
                    // publishing the event it's waiting for.
                    try await Task.sleep(for: .milliseconds(200))
                    _ = try await client.startINDIServer()
                    try await Task.sleep(for: .seconds(10))
                    return false
                }
                let result = try await group.next() ?? false
                group.cancelAll()
                return result
            }

            #expect(sawConnectionMade)

            _ = try await client.stopINDIServer()
            await client.disconnect()
        }
    }
}

extension ScriptRunStatus {
    fileprivate func isStarted(for runId: String) -> Bool {
        if case .started(let started) = self {
            return started.runId == runId
        }
        return false
    }
}

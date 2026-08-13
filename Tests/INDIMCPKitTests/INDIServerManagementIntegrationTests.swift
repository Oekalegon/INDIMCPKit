import Foundation
import Testing

@testable import INDIMCPKit

/// Exercises `INDIServerManagement` against a real, running INDIMCP-server.
///
/// Skipped unless `INDIMCP_TEST_SERVER_URL` is set (e.g.
/// `http://127.0.0.1:8123/mcp`), since CI has no INDIMCP-server (or `indiserver`
/// binary) available. Point it at a local `uv run indi-mcp --transport streamable-http
/// --host 127.0.0.1 --port 8123` to run this manually.
///
/// Bodies run under `IndiServerTestLock`, since `INDIMessagingIntegrationTests` and
/// `INDIRigReconciliationIntegrationTests` also start/stop this same shared `indiserver` process
/// and Swift Testing runs different suites concurrently by default — see that lock's doc comment.
@Suite("INDI server management (live server)")
struct INDIServerManagementIntegrationTests {
    @Test(
        "start, then stop, the managed indiserver process",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func startThenStop() async throws {
        try await IndiServerTestLock.withLock {
            let client = try await connectedTestClient()

            let started = try await client.startINDIServer()
            #expect(started.running == true)
            #expect(started.port == defaultINDIServerPort)

            let statusWhileRunning = try await client.getINDIServerStatus()
            #expect(statusWhileRunning.running == true)

            let stopped = try await client.stopINDIServer()
            #expect(stopped.running == false)

            await client.disconnect()
        }
    }

    @Test(
        "restart keeps the current port when none is given, and switches when one is",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func restartKeepsOrSwitchesPort() async throws {
        try await IndiServerTestLock.withLock {
            let client = try await connectedTestClient()

            _ = try await client.startINDIServer()

            let restartedSamePort = try await client.restartINDIServer()
            #expect(restartedSamePort.running == true)
            #expect(restartedSamePort.port == defaultINDIServerPort)

            let otherPort = defaultINDIServerPort + 1
            let restartedNewPort = try await client.restartINDIServer(port: otherPort)
            #expect(restartedNewPort.running == true)
            #expect(restartedNewPort.port == otherPort)

            _ = try await client.stopINDIServer()
            await client.disconnect()
        }
    }
}

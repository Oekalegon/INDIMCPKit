import Foundation
import Testing

@testable import INDIMCPKit

/// Exercises `INDIServerManagement` against a real, running INDIMCP-server.
///
/// Skipped unless `INDIMCP_TEST_SERVER_URL` is set (e.g.
/// `http://127.0.0.1:8123/mcp`), since CI has no INDIMCP-server (or `indiserver`
/// binary) available. Point it at a local `uv run indi-mcp --transport streamable-http
/// --host 127.0.0.1 --port 8123` to run this manually.
@Suite("INDI server management (live server)")
struct INDIServerManagementIntegrationTests {
    @Test(
        "start, then stop, the managed indiserver process",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func startThenStop() async throws {
        let client = try await connectedClient()

        let started = try await client.startINDIServer()
        #expect(started.running == true)
        #expect(started.port == defaultINDIServerPort)

        let statusWhileRunning = try await client.getINDIServerStatus()
        #expect(statusWhileRunning.running == true)

        let stopped = try await client.stopINDIServer()
        #expect(stopped.running == false)

        await client.disconnect()
    }

    @Test(
        "restart keeps the current port when none is given, and switches when one is",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func restartKeepsOrSwitchesPort() async throws {
        let client = try await connectedClient()

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

    private func connectedClient() async throws -> INDIMCPClient {
        let urlString = ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"]!
        let client = INDIMCPClient(endpoint: try #require(URL(string: urlString)))
        try await client.connect()
        return client
    }
}

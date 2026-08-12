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
        let urlString = ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"]!
        let endpoint = try #require(URL(string: urlString))
        let client = INDIMCPClient(endpoint: endpoint)
        try await client.connect()

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

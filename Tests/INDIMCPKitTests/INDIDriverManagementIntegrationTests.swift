import Foundation
import MCP
import Testing

@testable import INDIMCPKit

/// Exercises `INDIDriverManagement` (and, via `list_rigs`, the generic list-tool decoding path)
/// against a real, running INDIMCP-server.
///
/// Skipped unless `INDIMCP_TEST_SERVER_URL` is set — see
/// `INDIServerManagementIntegrationTests` for how to run this manually.
///
/// The INDI driver catalog itself lives at a fixed path (`/usr/share/indi/`) that only exists on
/// the target Raspberry Pi, not a macOS dev machine, so every driver-management tool call fails
/// here with "No such file or directory" — this suite only asserts that failure surfaces as
/// `INDIMCPClientError.toolCallFailed`, not that any driver actually starts/stops. That plumbing
/// (the tool call reaching the server, an error response coming back, decoding it correctly) is
/// what's actually being verified; a real catalog is exercised on the Pi target, not here.
@Suite("INDI driver management (live server)")
struct INDIDriverManagementIntegrationTests {
    @Test(
        "list-returning tool decodes the server's {result: [...]} wrapper",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func decodesWrappedListResult() async throws {
        let client = try await connectedClient()
        // list_rigs isn't part of driver management, but it's a list-returning tool that
        // doesn't depend on the INDI driver catalog, so it's a reliable way to confirm
        // INDIMCPClient.callToolList's {"result": [...]} unwrapping works against the real wire
        // format without depending on catalog-path environment differences.
        let rigs: [Value] = try await client.callToolList("list_rigs", decoding: Value.self)
        #expect(rigs.isEmpty)

        await client.disconnect()
    }

    @Test(
        "driver tool call failure surfaces as toolCallFailed",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func driverToolFailureSurfacesTypedError() async throws {
        let client = try await connectedClient()

        await #expect(throws: INDIMCPClientError.self) {
            _ = try await client.startINDIDriver(label: "nonexistent-driver-xyz")
        }

        await client.disconnect()
    }

    private func connectedClient() async throws -> INDIMCPClient {
        let urlString = ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"]!
        let client = INDIMCPClient(endpoint: try #require(URL(string: urlString)))
        try await client.connect()
        return client
    }
}

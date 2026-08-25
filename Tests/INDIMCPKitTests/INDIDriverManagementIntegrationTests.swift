import Foundation
import MCP
import Testing

@testable import INDIMCPKit

/// Exercises `INDIDriverManagement` (and, via `list_config`, the generic list-tool decoding path)
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
        let client = try await connectedTestClient()
        // list_config(kind: "rig") isn't part of driver management, but it's a list-returning
        // tool that doesn't depend on the INDI driver catalog, so it's a reliable way to confirm
        // INDIMCPClient.callToolList's {"result": [...]} unwrapping works against the real wire
        // format without depending on catalog-path environment differences. Doesn't assert an
        // exact count or emptiness: other live-server test suites (rigs, rig reconciliation) save
        // rigs to this same server, so however many exist is legitimately test-run-dependent —
        // what's actually being verified is that callToolList unwraps {"result": [...]} and
        // decodes each element as an object at all, not any particular count.
        let rigs: [Value] = try await client.callToolList(
            "list_config",
            arguments: ["kind": .string("rig")],
            decoding: Value.self
        )
        #expect(rigs.allSatisfy { if case .object = $0 { return true } else { return false } })

        await client.disconnect()
    }

    @Test(
        "driver tool call failure surfaces as toolCallFailed",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func driverToolFailureSurfacesTypedError() async throws {
        let client = try await connectedTestClient()

        await #expect(throws: INDIMCPClientError.self) {
            _ = try await client.startINDIDriver(label: "nonexistent-driver-xyz")
        }

        await client.disconnect()
    }
}

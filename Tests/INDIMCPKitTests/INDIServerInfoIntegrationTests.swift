import Foundation
import Testing

@testable import INDIMCPKit

/// Exercises `getServerInfo()` against a real, running INDIMCP-server.
///
/// Skipped unless `INDIMCP_TEST_SERVER_URL` is set — see `INDIServerManagementIntegrationTests`
/// for how to run this manually. Doesn't need a real `indiserver` or messaging connection —
/// `get_server_info` just reads the server's own package metadata and a build-timestamp file — so
/// this can run from a scratch directory like the rig/observatory suites.
@Suite("INDI server info (live server)")
struct INDIServerInfoIntegrationTests {
    @Test(
        "getServerInfo reports a version matching alignedINDIMCPServerVersion's format",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func reportsVersionAndBuildTimestamp() async throws {
        let client = try await connectedTestClient()

        let info = try await client.getServerInfo()
        #expect(!info.version.isEmpty)
        // Not asserting info.version == alignedINDIMCPServerVersion: this suite runs against
        // whatever INDIMCP-server checkout the developer points it at, which may be ahead of
        // (or behind) the version this kit is currently aligned to — that's exactly the drift
        // alignedINDIMCPServerVersion exists to let a consuming app detect, not something this
        // test should assume away. Asserting non-empty confirms the tool call and decode path
        // work end to end.

        await client.disconnect()
    }
}

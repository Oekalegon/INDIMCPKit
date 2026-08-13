import Foundation
import Testing

@testable import INDIMCPKit

/// Exercises `INDIMessaging` against a real, running INDIMCP-server with a real `indiserver`
/// process behind it.
///
/// Skipped unless `INDIMCP_TEST_SERVER_URL` is set — see `INDIServerManagementIntegrationTests`
/// for how to run this manually. Unlike driver management, messaging doesn't depend on the
/// (Raspberry-Pi-only) INDI driver catalog: starting the messaging stream just opens a TCP
/// connection to a running `indiserver`, so this suite also starts/stops `indiserver` itself
/// (via `INDIServerManagement`) to give messaging something to connect to.
///
/// Bodies run under `IndiServerTestLock`, since `INDIServerManagementIntegrationTests` and
/// `INDIRigReconciliationIntegrationTests` also start/stop this same shared `indiserver` process
/// and Swift Testing runs different suites concurrently by default — see that lock's doc comment.
@Suite("INDI messaging (live server)")
struct INDIMessagingIntegrationTests {
    @Test(
        "start/status/stop round-trip against a real indiserver",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func startStatusStop() async throws {
        try await IndiServerTestLock.withLock {
            let urlString = ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"]!
            let client = INDIMCPClient(endpoint: try #require(URL(string: urlString)))
            try await client.connect()

            _ = try await client.startINDIServer()

            let started = try await client.startINDIMessaging()
            #expect(started.running == true)

            let status = try await client.getINDIMessagingStatus()
            #expect(status.running == true)

            let messages = try await client.listINDIMessages(limit: 5)
            #expect(messages.count <= 5)

            let stopped = try await client.stopINDIMessaging()
            #expect(stopped.running == false)

            _ = try await client.stopINDIServer()
            await client.disconnect()
        }
    }

    @Test(
        "getDeviceProperties throws for a device the server has never seen",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func getDevicePropertiesThrowsForUnknownDevice() async throws {
        try await IndiServerTestLock.withLock {
            let urlString = ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"]!
            let client = INDIMCPClient(endpoint: try #require(URL(string: urlString)))
            try await client.connect()

            _ = try await client.startINDIServer()
            _ = try await client.startINDIMessaging()

            // The server raises ValueError for a device it's never seen (never connected, wrong
            // name, or offline) once its internal wait elapses — surfaced here as toolCallFailed.
            await #expect(throws: INDIMCPClientError.self) {
                _ = try await client.getDeviceProperties(device: "indimcpkit-test-\(UUID().uuidString)")
            }

            _ = try await client.stopINDIServer()
            await client.disconnect()
        }
    }
}

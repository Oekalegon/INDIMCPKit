import Foundation
import Testing

@testable import INDIMCPKit

/// Connects an `INDIMCPClient` to `INDIMCP_TEST_SERVER_URL` for a live-server integration test.
///
/// Every live-server suite needs exactly this — read the env var, construct a client, connect —
/// so it's shared here rather than copy-pasted per suite (as it was for six suites before this
/// was extracted). Callers are still responsible for checking `INDIMCP_TEST_SERVER_URL != nil` in
/// their own `.enabled(if:)` trait; this assumes it's already set.
func connectedTestClient() async throws -> INDIMCPClient {
    let urlString = ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"]!
    let client = INDIMCPClient(endpoint: try #require(URL(string: urlString)))
    try await client.connect()
    return client
}

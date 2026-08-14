import Foundation
import Testing

@testable import INDIMCPKit

/// Exercises `ObservableMessageStream` against a real, running INDIMCP-server.
///
/// This dev environment has no real INDI driver catalog (see `DeviceAbstractionsIntegrationTests`'
/// doc comment) — no messaging events ever actually flow with nothing connected, so this can't
/// exercise the live-update path for real (see `INDIEventStreamsIntegrationTests.
/// scriptEventsStreamsLiveUpdates` for how the equivalent scripting-layer stream *is* exercised
/// live, by actually running a script). It's scoped to what's verifiable without a driver: that
/// `start(device:)` completes with a confirmed initial (empty) window rather than hanging, that
/// `stop()`/a fresh `start(device:)` can be called repeatedly, and — the behavior this type exists
/// for — that rapidly oscillating the scoped device (A → B → A) doesn't hang or leave the stream
/// stuck unable to (re)subscribe, which is exactly the failure mode an unawaited unsubscribe could
/// produce (see this type's own doc comment).
@Suite("Observable message stream (live server)")
struct ObservableMessageStreamIntegrationTests {
    /// `start(device:)` only awaits the *previous* subscription's confirmed unsubscribe — like
    /// `ObservableDevice.start()`, it doesn't await the *new* subscription's first read, which
    /// happens inside `beginSubscription`'s independently-running `Task`. So `hasReceivedInitialWindow`
    /// becoming `true` has to be polled for rather than asserted immediately after `start` returns.
    private func waitForInitialWindow(
        _ stream: ObservableMessageStream, maxAttempts: Int = 50
    ) async throws {
        for _ in 0..<maxAttempts {
            if await stream.hasReceivedInitialWindow { return }
            try await Task.sleep(for: .milliseconds(100))
        }
        Issue.record("Timed out waiting for the initial window")
    }

    @Test(
        "start completes with a confirmed initial window",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func startCompletesWithConfirmedInitialWindow() async throws {
        let client = try await connectedTestClient()
        let stream = await ObservableMessageStream(client: client)

        await stream.start()
        try await waitForInitialWindow(stream)

        #expect(await stream.events.isEmpty)
        #expect(await stream.lastError == nil)

        await stream.stop()
        await client.disconnect()
    }

    @Test(
        "stop followed by a fresh start resets state and completes again",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func stopThenStartResetsAndCompletesAgain() async throws {
        let client = try await connectedTestClient()
        let stream = await ObservableMessageStream(client: client)

        await stream.start()
        try await waitForInitialWindow(stream)

        await stream.stop()
        await stream.start(device: "Not Connected Camera")
        try await waitForInitialWindow(stream)

        #expect(await stream.events.isEmpty)

        await stream.stop()
        await client.disconnect()
    }

    @Test(
        "rapidly oscillating the scoped device does not hang and leaves the last scope live",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func oscillatingDeviceDoesNotHang() async throws {
        let client = try await connectedTestClient()
        let stream = await ObservableMessageStream(client: client)

        // A → B → A, each awaited in turn the way MessageStreamView's `.task(id:)` awaits
        // `start(device:)` — exercises the exact sequence the awaited-unsubscribe-before-
        // resubscribe design is for. A version that instead fired a fire-and-forget unsubscribe
        // per switch could leave the last subscribe silently dropped server-side — which would
        // show up here as the final `waitForInitialWindow` timing out (recording an issue)
        // rather than the poll ever seeing `hasReceivedInitialWindow` flip to `true`.
        await stream.start(device: "Not Connected Camera")
        await stream.start(device: "Not Connected Mount")
        await stream.start(device: "Not Connected Camera")
        try await waitForInitialWindow(stream)

        #expect(await stream.events.isEmpty)

        await stream.stop()
        await client.disconnect()
    }
}

/// Serializes access to the one shared, real `indiserver` process that live-server integration
/// tests start/stop against `INDIMCP_TEST_SERVER_URL`.
///
/// Swift Testing runs tests from different suites concurrently by default — a `.serialized`
/// suite trait only serializes *within* one suite. `INDIServerManagementIntegrationTests`,
/// `INDIMessagingIntegrationTests`, and `INDIRigReconciliationIntegrationTests` all start/stop
/// the same external process, so without this, one test's `stopINDIServer()` mid-flight of
/// another's `startINDIMessaging()` is a real race (observed as a "[Errno 3] No such process"
/// failure the first time three suites overlapped). Any test that starts/stops `indiserver`
/// against a live server should wrap its body in `withIndiServerLock`.
///
/// Even with client-side calls fully serialized, occasional "[Errno 3] No such process" failures
/// can still surface from `stopINDIServer()`/`restartINDIServer()`. Root cause traced to
/// INDIMCP-server itself, not a client concurrency bug: `indi_server.stop_server()`
/// (`indi_server.py`) kills the process twice — once via `indiweb.IndiServer.stop()`'s
/// psutil-based scan (which exception-handles a since-exited process fine), then
/// unconditionally again via its own `_async_cmd.terminate()`, which has no exception handling
/// at all. If the first kill already reaped the process (`proc.wait()` blocks until it does),
/// the second, redundant terminate call's `os.killpg` raises a bare `ProcessLookupError` that
/// propagates all the way up as a tool error. `release()` waiting briefly before waking the next
/// waiter reduces how often this is hit but can't eliminate it, since it's a genuine server bug
/// (worth fixing upstream in INDIMCP-server, out of scope for this kit) rather than a timing
/// window this client can fully control.
actor IndiServerTestLock {
    static let shared = IndiServerTestLock()

    private var locked = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    private func acquire() async {
        if !locked {
            locked = true
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    private func release() async {
        try? await Task.sleep(for: .milliseconds(300))
        if waiters.isEmpty {
            locked = false
        } else {
            waiters.removeFirst().resume()
        }
    }

    static func withLock<T: Sendable>(_ body: () async throws -> T) async rethrows -> T {
        await shared.acquire()
        do {
            let result = try await body()
            await shared.release()
            return result
        } catch {
            await shared.release()
            throw error
        }
    }
}

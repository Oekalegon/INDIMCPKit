import Foundation
import Testing

@testable import INDIMCPKit

/// Exercises `INDIScriptRuns` against a real, running INDIMCP-server with a real `indiserver`
/// process behind it.
///
/// Skipped unless `INDIMCP_TEST_SERVER_URL` is set — see `INDIServerManagementIntegrationTests`
/// for how to run this manually. Run the server from the actual INDIMCP-server checkout (like
/// `INDIScriptsIntegrationTests`, not a scratch directory) so the built-in `park` script is
/// loaded. There's no connected mount driver in this dev environment (no INDI driver catalog on
/// macOS — see `INDIDriverManagementIntegrationTests`), so every run started here fails quickly
/// with a `.failed` status rather than ever actually parking anything — that failure path, and
/// the plumbing around it (start → poll → terminal status, cancel/pause/resume rejection), is
/// what's actually being verified.
@Suite("INDI script runs (live server)")
struct INDIScriptRunsIntegrationTests {
    @Test(
        "run park against a rig with no connected mount; status settles to failed",
        .enabled(if: ProcessInfo.processInfo.environment["INDIMCP_TEST_SERVER_URL"] != nil)
    )
    func runFailsWithoutConnectedDevice() async throws {
        try await IndiServerTestLock.withLock {
            let client = try await connectedTestClient()
            _ = try await client.startINDIServer()
            _ = try await client.startINDIMessaging()

            let rig = Rig(
                id: "indimcpkit-test-\(UUID().uuidString)",
                name: "Script Run Test Rig",
                components: [Component(role: .mount, id: "mnt1", device: "Not Connected Mount")]
            )
            _ = try await client.saveRig(rig)

            let started = try await client.runScript(scriptId: "park", rigId: rig.id)
            #expect(started.script == "park")
            #expect(started.rigId == rig.id)
            #expect(started.pausable == false)

            // The run fails almost immediately (the mount device isn't connected), but is
            // asynchronous server-side — poll briefly rather than assuming it's already terminal.
            var status = try await client.getScriptStatus(runId: started.runId)
            for _ in 0..<20 {
                if case .failed = status { break }
                if case .completed = status { break }
                try await Task.sleep(for: .milliseconds(100))
                status = try await client.getScriptStatus(runId: started.runId)
            }
            guard case .failed(let failed) = status else {
                Testing.Issue.record("expected a .failed status, got \(status)")
                return
            }
            #expect(failed.runId == started.runId)
            #expect(failed.rigId == rig.id)

            // cancelScript on an already-terminal run doesn't error — it just returns the
            // terminal status as-is (confirmed against the real server).
            let cancelled = try await client.cancelScript(runId: started.runId)
            guard case .failed = cancelled else {
                Testing.Issue.record("expected cancelScript on a terminal run to return .failed, got \(cancelled)")
                return
            }

            // park isn't pausable, and the run has already finished either way — both
            // pauseScript and resumeScript must reject it.
            guard case .rejected = try await client.pauseScript(runId: started.runId) else {
                Testing.Issue.record("expected pauseScript to reject a non-pausable/terminal run")
                return
            }
            guard case .rejected = try await client.resumeScript(runId: started.runId) else {
                Testing.Issue.record("expected resumeScript to reject a non-pausable/terminal run")
                return
            }

            _ = try await client.stopINDIServer()
            await client.disconnect()
        }
    }
}

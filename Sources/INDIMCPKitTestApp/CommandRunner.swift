import Foundation
import INDIMCPKit
import Observation

/// Runs one device command, then polls `getScriptStatus` until the run reaches a terminal state,
/// publishing progress for a SwiftUI view to reflect — never assuming success just because the
/// command call itself returned.
@MainActor
@Observable
final class CommandRunner {
    enum State {
        case idle
        case starting
        case running(ScriptRunStatus)
        case finished(ScriptRunStatus)
        case failed(String)
    }

    private(set) var state = State.idle
    private let client: INDIMCPClient

    init(client: INDIMCPClient) {
        self.client = client
    }

    /// Runs `start`, then polls the resulting run's status until it reaches a terminal state
    /// (`ScriptRunStatus.isTerminal`) or polling gives up after a fixed number of attempts. Polls
    /// itself, rather than calling `INDIMCPClient.waitForTerminalStatus`, because it needs to
    /// publish each intermediate status for the UI — `waitForTerminalStatus` only reports the
    /// final one.
    func run(_ start: @Sendable () async throws -> ScriptRunStarted) async {
        state = .starting
        do {
            let started = try await start()
            await poll(runId: started.runId)
        } catch {
            state = .failed(String(describing: error))
        }
    }

    private func poll(runId: String) async {
        for _ in 0..<120 {
            do {
                let status = try await client.getScriptStatus(runId: runId)
                if status.isTerminal {
                    state = .finished(status)
                    return
                }
                state = .running(status)
            } catch {
                state = .failed(String(describing: error))
                return
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
        state = .failed("Gave up polling '\(runId)' for a terminal status.")
    }
}

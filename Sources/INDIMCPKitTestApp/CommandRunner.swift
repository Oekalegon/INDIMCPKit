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

    /// Runs `start`, then polls the resulting run's status until it reaches a terminal state or
    /// polling gives up after a fixed number of attempts (this is a test app, not a production
    /// client — a caller that needs an unbounded wait should poll `getScriptStatus` directly).
    func run(_ start: @Sendable () async throws -> ScriptRunStarted) async {
        state = .starting
        do {
            let started = try await start()
            await poll(runId: started.runId)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func poll(runId: String) async {
        for _ in 0..<120 {
            do {
                let status = try await client.getScriptStatus(runId: runId)
                if Self.isTerminal(status) {
                    state = .finished(status)
                    return
                }
                state = .running(status)
            } catch {
                state = .failed(error.localizedDescription)
                return
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
        state = .failed("Gave up polling '\(runId)' for a terminal status.")
    }

    private static func isTerminal(_ status: ScriptRunStatus) -> Bool {
        switch status {
        case .completed, .failed, .cancelled, .paused, .pauseRejected:
            return true
        case .started, .progress, .resumed:
            return false
        }
    }
}

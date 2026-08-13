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
    private var activeRun: Task<Void, Never>?

    /// Whether a command is currently starting or being polled — callers should disable their
    /// action buttons while this is true, since firing a second command on top of an in-flight
    /// one cancels the first (see `run`) rather than running both.
    var isBusy: Bool {
        switch state {
        case .starting, .running: return true
        case .idle, .finished, .failed: return false
        }
    }

    init(client: INDIMCPClient) {
        self.client = client
    }

    /// Runs `start`, then polls the resulting run's status until it reaches a terminal state
    /// (`ScriptRunStatus.isTerminal`) or polling gives up after a fixed number of attempts. Polls
    /// itself, rather than calling `INDIMCPClient.waitForTerminalStatus`, because it needs to
    /// publish each intermediate status for the UI — `waitForTerminalStatus` only reports the
    /// final one.
    ///
    /// Cancels any still-in-flight previous run first: without this, two overlapping runs' polls
    /// both keep writing to `state` as their responses arrive, and the UI flip-flops between
    /// whichever one's poll happened to land last — not a server or kit bug, just two independent
    /// pollers racing to update one piece of state.
    func run(_ start: @escaping @Sendable () async throws -> ScriptRunStarted) async {
        activeRun?.cancel()
        state = .starting
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let started = try await start()
                await self.poll(runId: started.runId)
            } catch {
                if !Task.isCancelled {
                    self.state = .failed(String(describing: error))
                }
            }
        }
        activeRun = task
        await task.value
    }

    private func poll(runId: String) async {
        for _ in 0..<120 {
            if Task.isCancelled { return }
            do {
                let status = try await client.getScriptStatus(runId: runId)
                if Task.isCancelled { return }
                if status.isTerminal {
                    state = .finished(status)
                    return
                }
                state = .running(status)
            } catch {
                if !Task.isCancelled {
                    state = .failed(String(describing: error))
                }
                return
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
        if !Task.isCancelled {
            state = .failed("Gave up polling '\(runId)' for a terminal status.")
        }
    }
}

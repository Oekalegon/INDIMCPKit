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
        case cancelling
        case finished(ScriptRunStatus)
        case failed(String)
    }

    private(set) var state = State.idle
    private let client: INDIMCPClient
    private var activeRun: Task<Void, Never>?
    private var currentRunId: String?

    /// Whether a command is currently starting, being polled, or being cancelled — callers should
    /// disable their action buttons while this is true, since firing a second command on top of an
    /// in-flight one cancels the first (see `run`) rather than running both.
    var isBusy: Bool {
        switch state {
        case .starting, .running, .cancelling: return true
        case .idle, .finished, .failed: return false
        }
    }

    init(client: INDIMCPClient) {
        self.client = client
    }

    /// Runs `start`, then polls the resulting run's status until it reaches a terminal state
    /// (`ScriptRunStatus.isTerminal`). Polls itself, rather than calling
    /// `INDIMCPClient.waitForTerminalStatus`, because it needs to publish each intermediate status
    /// for the UI — `waitForTerminalStatus` only reports the final one.
    ///
    /// No client-side give-up bound: real commands legitimately vary from sub-second (a filter
    /// change) to several minutes (`cool_camera` defaults to a 300s timeout, and can need longer
    /// on a hot day) to a long exposure's caller-chosen duration, so any fixed cap is either too
    /// short for a real run or pointlessly long for a fast one. The run keeps going server-side
    /// regardless of whether this app is watching it, and its own script-level timeout is what
    /// actually bounds it; this only stops watching early if cancelled by a newer command.
    ///
    /// Cancels any still-in-flight previous run first: without this, two overlapping runs' polls
    /// both keep writing to `state` as their responses arrive, and the UI flip-flops between
    /// whichever one's poll happened to land last — not a server or kit bug, just two independent
    /// pollers racing to update one piece of state.
    func run(_ start: @escaping @Sendable () async throws -> ScriptRunStarted) async {
        activeRun?.cancel()
        state = .starting
        currentRunId = nil
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let started = try await start()
                self.currentRunId = started.runId
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

    /// Cancels the currently in-flight run, both locally (stop polling) and server-side (via
    /// `cancelScript`, so the run actually stops rather than continuing unwatched) — the
    /// operator's way out now that `poll` has no built-in give-up bound.
    ///
    /// `cancelScript` itself can block until the run's current step finishes (see its doc
    /// comment) — that's surfaced here as `.cancelling` while in flight, then `.finished`/
    /// `.failed` normally, rather than this call hanging silently.
    ///
    /// `currentRunId` can still be `nil` here even though a command is visibly in progress: `run`
    /// clears it synchronously before its `start()` call has necessarily reached the server, so a
    /// `cancel()` landing in that narrow window has nothing to call `cancelScript` on yet. This
    /// only cancels the local watch in that case — if `start()` had, in fact, already reached the
    /// server, that run keeps going unwatched and uncancelled until it resolves on its own, the
    /// same accepted trade-off as `coolerOff` overriding an in-progress `coolCamera` without
    /// explicitly cancelling it first.
    func cancel() async {
        activeRun?.cancel()
        guard let runId = currentRunId else {
            state = .idle
            return
        }
        state = .cancelling
        do {
            let status = try await client.cancelScript(runId: runId)
            state = .finished(status)
        } catch {
            state = .failed(String(describing: error))
        }
    }

    private func poll(runId: String) async {
        while true {
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
    }
}

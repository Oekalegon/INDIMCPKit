import INDIMCPKit
import SwiftUI

/// Renders a `CommandRunner`'s current state — never shows "done" until the run's status has
/// actually been polled to a terminal state, not just because the initial call returned.
struct CommandStatusView: View {
    let state: CommandRunner.State

    /// Cancels the run currently backing `state` — offered whenever a run could still be going,
    /// since polling itself has no give-up bound (a real command can legitimately take minutes)
    /// and this is the operator's only way to stop watching (and actually stop, server-side) one
    /// that's stuck or just taking longer than wanted.
    var onCancel: (() -> Void)?

    var body: some View {
        switch state {
        case .idle:
            EmptyView()
        case .starting:
            HStack {
                Label("Starting…", systemImage: "hourglass")
                    .foregroundStyle(.secondary)
                cancelButton
            }
        case .running(let status):
            HStack {
                Label(description(for: status), systemImage: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.secondary)
                cancelButton
            }
        case .cancelling:
            Label("Cancelling…", systemImage: "xmark.circle")
                .foregroundStyle(.secondary)
        case .finished(let status):
            Label(description(for: status), systemImage: symbol(for: status))
                .foregroundStyle(color(for: status))
                .textSelection(.enabled)
        case .failed(let message):
            Label(message, systemImage: "xmark.octagon")
                .foregroundStyle(.red)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private var cancelButton: some View {
        if let onCancel {
            Spacer()
            Button("Cancel", action: onCancel)
        }
    }

    private func description(for status: ScriptRunStatus) -> String {
        switch status {
        case .started(let started):
            return "Started '\(started.script)' (run \(started.runId.prefix(8)))"
        case .progress(let progress):
            if let total = progress.totalSteps {
                return "Step \(progress.step) of \(total)" + (progress.message.map { ": \($0)" } ?? "")
            }
            return progress.message ?? "Step \(progress.step)"
        case .completed(let completed):
            return "Completed (\(completed.result.stepsExecuted) step(s))"
        case .failed(let failed):
            return "Failed at step \(failed.failedAtStep): \(failed.error.message)"
        case .cancelled:
            return "Cancelled"
        case .paused(let paused):
            return "Paused at step \(paused.pausedAtStep)"
        case .resumed(let resumed):
            return "Resumed at step \(resumed.resumedAtStep)"
        case .pauseRejected(let rejected):
            return "Pause/resume rejected: \(rejected.reason)"
        }
    }

    private func symbol(for status: ScriptRunStatus) -> String {
        switch status {
        case .completed: return "checkmark.circle"
        case .failed: return "xmark.octagon"
        case .cancelled: return "stop.circle"
        case .paused: return "pause.circle"
        case .pauseRejected: return "exclamationmark.triangle"
        default: return "checkmark.circle"
        }
    }

    private func color(for status: ScriptRunStatus) -> Color {
        switch status {
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .orange
        case .paused: return .yellow
        case .pauseRejected: return .orange
        default: return .primary
        }
    }
}

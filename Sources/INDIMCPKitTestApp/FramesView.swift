import Foundation
import INDIMCPKit
import SwiftUI

struct FramesView: View {
    @State private var model: FramesModel

    init(client: INDIMCPClient) {
        _model = State(initialValue: FramesModel(client: client))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
                    .padding([.horizontal, .top])
            }

            if model.frames.isEmpty {
                ContentUnavailableView(
                    model.isLoading ? "Loading…" : "No Frames",
                    systemImage: "photo.on.rectangle",
                    description: Text(model.isLoading ? "" : "No frames have been captured on this server yet.")
                )
            } else {
                List(model.frames, id: \.frameId) { frame in
                    FrameRow(frame: frame, state: model.downloadState(for: frame)) {
                        Task { await model.download(frame) }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("Refresh") { Task { await model.refresh() } }
                    .disabled(model.isLoading)
            }
        }
        .task { await model.refresh() }
    }
}

private struct FrameRow: View {
    let frame: FrameMetadataResponse
    let state: FramesModel.DownloadState
    let onDownload: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(frame.device)
                    .font(.headline)
                Text("\(frame.frameId.prefix(8))… · \(formattedSize) · \(frame.capturedAt)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                issuesLabels
                statusLabel
            }

            Spacer()

            Button(state == .downloading ? "Downloading…" : "Download", action: onDownload)
                .disabled(state == .downloading)
        }
        .padding(.vertical, 4)
    }

    /// Conditions the server itself reported about this frame's metadata — e.g. a
    /// `frameChecksumMissing` warning for a frame that predates checksum support (INDIMCP-107).
    /// Shown regardless of download state, since these are about the frame as captured, not
    /// about this app's own download/confirm workflow — that's what `statusLabel` covers.
    @ViewBuilder
    private var issuesLabels: some View {
        ForEach(Array(frame.issues.enumerated()), id: \.offset) { _, issue in
            Label(issue.message, systemImage: issue.severity.testAppSymbolName)
                .font(.caption)
                .foregroundStyle(issue.severity.testAppTintColor)
                .lineLimit(2)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch state {
        case .idle:
            if frame.transferredAt != nil {
                Label("Already confirmed transferred", systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .downloading:
            EmptyView()
        case .succeeded(let destination):
            Label("Saved to \(destination.lastPathComponent) and confirmed", systemImage: "checkmark.circle")
                .font(.caption)
                .foregroundStyle(.green)
        case .downloadedNotConfirmed(let destination, let reason):
            Label("Saved to \(destination.lastPathComponent), not confirmed: \(reason)", systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
                .lineLimit(2)
                .textSelection(.enabled)
        case .failed(let message):
            Label(message, systemImage: "xmark.octagon")
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(2)
                .textSelection(.enabled)
        }
    }

    private var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(frame.sizeBytes), countStyle: .file)
    }
}

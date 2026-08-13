import Foundation
import INDIMCPKit
import Observation

/// Backs `FramesView` — lists frames captured on the server and downloads them to a local file,
/// tracking each frame's download state independently so multiple downloads can be in flight (or
/// have failed/succeeded) at once without one clobbering another's status.
@MainActor
@Observable
final class FramesModel {
    enum DownloadState: Equatable {
        case idle
        case downloading
        /// Downloaded, its local size matched the server-reported `sizeBytes`, and
        /// `confirmFrameTransfer` succeeded.
        case succeeded(URL)
        /// Downloaded, but not confirmed — either the local file's size didn't match what the
        /// server reported (a real integrity concern, not just a formality), or it matched but
        /// the `confirmFrameTransfer` call itself failed. Either way the file is still on disk at
        /// `destination`, just not marked as safely transferred server-side.
        case downloadedNotConfirmed(destination: URL, reason: String)
        case failed(String)
    }

    private let client: INDIMCPClient

    private(set) var frames: [FrameMetadataResponse] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var downloadStates: [String: DownloadState] = [:]

    init(client: INDIMCPClient) {
        self.client = client
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        do {
            frames = try await client.listFrames()
        } catch {
            errorMessage = String(describing: error)
        }
        isLoading = false
    }

    func downloadState(for frame: FrameMetadataResponse) -> DownloadState {
        downloadStates[frame.frameId] ?? .idle
    }

    /// Downloads `frame` to the user's Downloads folder, then — since the server doesn't expose a
    /// real checksum for a frame anywhere yet (`frame_store`'s schema has no hash column; see
    /// IMCPKIT-23) — verifies what's actually available: the downloaded file's size against the
    /// server-reported `sizeBytes`. Only calls `confirmFrameTransfer` if that matches; a mismatch
    /// is left as `.downloadedNotConfirmed` rather than silently confirmed, since a truncated or
    /// corrupted transfer is exactly the thing `confirmFrameTransfer`'s own doc comment warns
    /// against confirming.
    ///
    /// The server never tells a client the frame's on-disk path or original filename via
    /// `listFrames`/`getFrameMetadata` (deliberately — see `FrameMetadata`'s doc comment), so
    /// there's no extension to recover here beyond guessing; `.fits` matches every built-in
    /// capture script's own convention.
    func download(_ frame: FrameMetadataResponse) async {
        // Guarded and set synchronously (no await before this point), so a rapid double-tap on
        // the same row's Download button can't schedule two overlapping downloads for the same
        // frame before the first one's .downloading state has a chance to disable the button.
        guard downloadState(for: frame) != .downloading else { return }
        downloadStates[frame.frameId] = .downloading

        guard let downloadsDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        else {
            downloadStates[frame.frameId] = .failed("No Downloads folder available.")
            return
        }
        let sanitizedDevice = frame.device.replacingOccurrences(of: "/", with: "-")
        let destination = downloadsDirectory.appendingPathComponent("\(sanitizedDevice)-\(frame.frameId).fits")

        do {
            try await client.downloadFrame(frame, to: destination)
        } catch {
            downloadStates[frame.frameId] = .failed(String(describing: error))
            return
        }

        let actualSize = (try? destination.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
        guard actualSize == frame.sizeBytes else {
            let actualDescription = actualSize.map(String.init) ?? "unknown"
            downloadStates[frame.frameId] = .downloadedNotConfirmed(
                destination: destination,
                reason: "Size mismatch: server reported \(frame.sizeBytes) bytes, downloaded file is \(actualDescription)."
            )
            return
        }

        do {
            _ = try await client.confirmFrameTransfer(frameId: frame.frameId)
            downloadStates[frame.frameId] = .succeeded(destination)
        } catch {
            downloadStates[frame.frameId] = .downloadedNotConfirmed(
                destination: destination,
                reason: "Size verified, but confirming the transfer with the server failed: \(String(describing: error))"
            )
        }
    }
}

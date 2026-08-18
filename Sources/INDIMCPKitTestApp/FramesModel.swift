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
        /// Downloaded, its local content passed verification — a checksum comparison for a frame
        /// that has one, a size comparison as a fallback for a legacy frame that doesn't (see
        /// `download(_:)`) — and `confirmFrameTransfer` succeeded.
        case succeeded(URL)
        /// Downloaded, but not confirmed — either verification failed (a real integrity concern,
        /// not just a formality), or it passed but the `confirmFrameTransfer` call itself failed.
        /// Either way the file is still on disk at `destination`, just not marked as safely
        /// transferred server-side.
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

    /// Downloads `frame` to the user's Downloads folder, then verifies the downloaded file's
    /// actual content before ever confirming the transfer: a real SHA-256 comparison via
    /// `verifyChecksum(ofFileAt:)` for a frame that has one (every frame captured since
    /// INDIMCP-95), falling back to a size comparison against `sizeBytes` only for a legacy frame
    /// that predates checksum support (`checksumSha256 == nil`) — a size match alone can't catch
    /// a same-length-but-corrupted transfer the way a hash comparison can. Only calls
    /// `confirmFrameTransfer` once verification passes; a failure is left as
    /// `.downloadedNotConfirmed` rather than silently confirmed, since a truncated or corrupted
    /// transfer is exactly the thing `confirmFrameTransfer`'s own doc comment warns against
    /// confirming.
    ///
    /// See `FrameMetadataResponse.suggestedLocalFilename` for the local filename this uses and
    /// why it's a guess rather than a fact recovered from the server.
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
        let destination = downloadsDirectory.appendingPathComponent(frame.suggestedLocalFilename)

        do {
            try await client.downloadFrame(frame, to: destination)
        } catch {
            downloadStates[frame.frameId] = .failed(String(describing: error))
            return
        }

        let verification: ChecksumVerification
        do {
            verification = try frame.verifyChecksum(ofFileAt: destination)
        } catch {
            downloadStates[frame.frameId] = .downloadedNotConfirmed(
                destination: destination,
                reason: "Downloaded, but verifying the file's checksum failed: \(String(describing: error))"
            )
            return
        }

        switch verification {
        case .mismatched(let expected, let actual):
            downloadStates[frame.frameId] = .downloadedNotConfirmed(
                destination: destination,
                reason: "Checksum mismatch: server reported \(expected), downloaded file hashes to \(actual)."
            )
            return
        case .matched:
            break
        case .noChecksumAvailable:
            let actualSize = (try? destination.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
            guard actualSize == frame.sizeBytes else {
                let actualDescription = actualSize.map(String.init) ?? "unknown"
                downloadStates[frame.frameId] = .downloadedNotConfirmed(
                    destination: destination,
                    reason: "Size mismatch: server reported \(frame.sizeBytes) bytes, downloaded file is \(actualDescription)."
                )
                return
            }
        }

        do {
            _ = try await client.confirmFrameTransfer(frameId: frame.frameId)
            downloadStates[frame.frameId] = .succeeded(destination)
        } catch {
            downloadStates[frame.frameId] = .downloadedNotConfirmed(
                destination: destination,
                reason: "Verified, but confirming the transfer with the server failed: \(String(describing: error))"
            )
        }
    }
}

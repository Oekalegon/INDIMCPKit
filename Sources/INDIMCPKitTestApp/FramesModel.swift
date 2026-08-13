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
        case succeeded(URL)
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

    /// Downloads `frame` to the user's Downloads folder. The server never tells a client the
    /// frame's on-disk path or original filename via `listFrames`/`getFrameMetadata` (deliberately
    /// — see `FrameMetadata`'s doc comment), so there's no extension to recover here beyond
    /// guessing; `.fits` matches every built-in capture script's own convention.
    func download(_ frame: FrameMetadataResponse) async {
        downloadStates[frame.frameId] = .downloading
        do {
            guard let downloadsDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            else {
                downloadStates[frame.frameId] = .failed("No Downloads folder available.")
                return
            }
            let sanitizedDevice = frame.device.replacingOccurrences(of: "/", with: "-")
            let destination = downloadsDirectory.appendingPathComponent("\(sanitizedDevice)-\(frame.frameId).fits")
            try await client.downloadFrame(frame, to: destination)
            downloadStates[frame.frameId] = .succeeded(destination)
        } catch {
            downloadStates[frame.frameId] = .failed(String(describing: error))
        }
    }
}

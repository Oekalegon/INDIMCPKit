import Foundation

extension INDIMCPClient {
    /// Downloads `frame`'s raw bytes from its `downloadUrl` to `destination`, overwriting any
    /// existing file there.
    ///
    /// Uses `URLSession`'s download task (not `data(from:)`), which streams straight to a
    /// temporary file on disk as the transfer happens — never buffering a whole frame's bytes in
    /// memory. This mirrors the server's own reasoning for building `GET /frames/{frameId}` as a
    /// plain streamed HTTP route in the first place (INDIMCP-89): a multi-megabyte dark frame
    /// read entirely into memory (client or server side) is exactly the failure mode that route
    /// replaced.
    ///
    /// Plain, unauthenticated HTTP — same trust model as every other call this server accepts
    /// (see `docs/Deployment.md`'s Hardening notes), not an MCP tool call, so this doesn't go
    /// through `callTool`.
    public func downloadFrame(_ frame: FrameMetadataResponse, to destination: URL) async throws {
        guard let downloadUrlString = frame.downloadUrl, let url = URL(string: downloadUrlString) else {
            throw INDIMCPClientError.frameNotDownloadable(frameId: frame.frameId)
        }
        try await Self.download(from: url, to: destination, frameId: frame.frameId)
    }

    /// Looks up `frameId`'s current metadata via `getFrameMetadata`, then downloads it — a
    /// convenience for a caller that only has a `frameId` on hand, not the full
    /// `FrameMetadataResponse` `listFrames`/`getFrameMetadata` already returned.
    public func downloadFrame(frameId: String, to destination: URL) async throws {
        let metadata = try await getFrameMetadata(frameId: frameId)
        try await downloadFrame(metadata, to: destination)
    }

    private static func download(from url: URL, to destination: URL, frameId: String) async throws {
        let (temporaryURL, response) = try await URLSession.shared.download(from: url)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw INDIMCPClientError.frameDownloadFailed(frameId: frameId, statusCode: statusCode)
        }

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destination.path) {
            // Atomic swap rather than remove-then-move: if moveItem below failed after an
            // unconditional removeItem, the caller would be left with neither the old file nor
            // the new one — a real way to lose a previously-downloaded frame's only local copy
            // to a transient filesystem error.
            _ = try fileManager.replaceItemAt(destination, withItemAt: temporaryURL)
        } else {
            try fileManager.moveItem(at: temporaryURL, to: destination)
        }
    }
}

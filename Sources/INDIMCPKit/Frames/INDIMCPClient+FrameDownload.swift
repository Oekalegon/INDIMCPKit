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
        try await download(from: reachableURL(for: url), to: destination, frameId: frame.frameId)
    }

    /// Looks up `frameId`'s current metadata via `getFrameMetadata`, then downloads it — a
    /// convenience for a caller that only has a `frameId` on hand, not the full
    /// `FrameMetadataResponse` `listFrames`/`getFrameMetadata` already returned.
    public func downloadFrame(frameId: String, to destination: URL) async throws {
        let metadata = try await getFrameMetadata(frameId: frameId)
        try await downloadFrame(metadata, to: destination)
    }

    /// Downloads every captured frame belonging to `runId` into `directory`, one file per frame,
    /// named per `FrameMetadataResponse.suggestedLocalFilename` — the same naming
    /// `INDIMCPKitTestApp`'s `FramesModel` already uses when downloading a single frame by hand,
    /// so a frame downloaded through this convenience lands under the same name a caller would
    /// already expect if they'd downloaded it one at a time.
    ///
    /// Composes `listFrames(runId:)` with `downloadFrame(_:to:)` per frame — there's no single
    /// server tool for "download this whole run". Creates `directory` (with any missing
    /// intermediate directories) only once `listFrames` has succeeded, so a server/network
    /// failure never leaves an empty directory behind as a side effect.
    ///
    /// Not atomic across frames, same as `deleteAllFrames`: if a `downloadFrame` call partway
    /// through the list throws, this rethrows immediately — some frames may already be on disk
    /// and others not. Call `listFrames(runId:)` again afterward, or check `directory`'s
    /// contents, to see what's actually there rather than assuming all-or-nothing.
    public func downloadAllFrames(runId: String, to directory: URL) async throws -> [FrameMetadataResponse] {
        let frames = try await listFrames(runId: runId)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        var downloaded: [FrameMetadataResponse] = []
        for frame in frames {
            let destination = directory.appendingPathComponent(frame.suggestedLocalFilename)
            try await downloadFrame(frame, to: destination)
            downloaded.append(frame)
        }
        return downloaded
    }

    /// Substitutes this client's own connection host for `url`'s host — used on a frame's
    /// `downloadUrl` above.
    ///
    /// INDIMCP-server computes `downloadUrl` from its own `socket.gethostname()` (an mDNS
    /// `.local` name, confirmed against the server's `_frame_download_url` doc comment), which
    /// isn't reliably resolvable from every client's network — mDNS can be disabled, blocked
    /// across subnets, or simply not configured — even though the exact same server is already
    /// reachable at whatever host this client used to connect via MCP in the first place (`endpoint`).
    /// Swapping in that already-proven-reachable host, while keeping `url`'s own scheme/port/path
    /// exactly as the server returned them, sidesteps hostname-resolution failures entirely
    /// without needing any server-side change. A no-op if the hosts already match.
    func reachableURL(for url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let endpointHost = endpoint.host,
            components.host != endpointHost
        else {
            return url
        }
        components.host = endpointHost
        return components.url ?? url
    }

    /// Streams `url` to a temporary file via `URLSession`'s download task, checks for a 2xx
    /// response, then atomically installs it at `destination`.
    private func download(from url: URL, to destination: URL, frameId: String) async throws {
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

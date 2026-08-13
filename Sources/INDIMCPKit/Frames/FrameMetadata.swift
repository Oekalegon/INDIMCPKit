/// Metadata for one captured frame — never the frame's on-disk path, which is an internal
/// server-side detail; see `FrameMetadataResponse.downloadUrl` for how to actually fetch it.
///
/// Mirrors INDIMCP-server's `FrameMetadata` (`frame_store.py`). `runId` is `nil` for a frame
/// captured ad hoc (a direct `capture_frame` call, not through a script run).
public struct FrameMetadata: Codable, Sendable, Hashable {
    public let frameId: String
    public let runId: String?
    public let device: String
    public let sizeBytes: Int
    public let capturedAt: String
    public let transferredAt: String?

    public init(
        frameId: String,
        runId: String?,
        device: String,
        sizeBytes: Int,
        capturedAt: String,
        transferredAt: String?
    ) {
        self.frameId = frameId
        self.runId = runId
        self.device = device
        self.sizeBytes = sizeBytes
        self.capturedAt = capturedAt
        self.transferredAt = transferredAt
    }
}

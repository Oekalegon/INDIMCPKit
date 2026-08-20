/// Metadata for one captured frame — never the frame's on-disk path, which is an internal
/// server-side detail; see `FrameMetadataResponse.downloadUrl` for how to actually fetch it.
///
/// Mirrors INDIMCP-server's `FrameMetadata` (`frame_store.py`). `runId` is `nil` for a frame
/// captured ad hoc (a direct `capture_frame` call, not through a script run).
public struct FrameMetadata: Codable, Sendable, Hashable {
    /// The frame's unique, server-assigned identifier.
    public let frameId: String
    /// The script run that captured this frame, if any — `nil` for an ad hoc `capture_frame` call
    /// not made through a script.
    public let runId: String?
    /// The camera device that captured this frame.
    public let device: String
    /// The frame file's size in bytes, as last recorded server-side.
    public let sizeBytes: Int
    /// The frame file's SHA-256 checksum, as a lowercase hex string — lets a caller verify a
    /// downloaded file's actual content, not just its length against `sizeBytes` (a
    /// truncated-but-coincidentally-same-length transfer would pass a size check but fail a hash
    /// comparison). See `FrameMetadataResponse.verifyChecksum(ofFileAt:)`.
    ///
    /// `nil` only for a frame captured before checksum support existed server-side
    /// (INDIMCP-95) — its database row was carried forward by a schema migration with nothing
    /// left to hash. Every frame captured since always has one.
    public let checksumSha256: String?
    /// When this frame was captured, as an ISO 8601 timestamp string.
    public let capturedAt: String
    /// When `confirmFrameTransfer` was called for this frame, or `nil` if it hasn't been yet.
    public let transferredAt: String?

    /// Creates a new frame metadata record.
    public init(
        frameId: String,
        runId: String?,
        device: String,
        sizeBytes: Int,
        checksumSha256: String?,
        capturedAt: String,
        transferredAt: String?
    ) {
        self.frameId = frameId
        self.runId = runId
        self.device = device
        self.sizeBytes = sizeBytes
        self.checksumSha256 = checksumSha256
        self.capturedAt = capturedAt
        self.transferredAt = transferredAt
    }
}

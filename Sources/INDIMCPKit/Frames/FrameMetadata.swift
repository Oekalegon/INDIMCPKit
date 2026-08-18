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
    /// The frame file's SHA-256 checksum, as a lowercase hex string — lets a caller verify a
    /// downloaded file's actual content, not just its length against `sizeBytes` (a
    /// truncated-but-coincidentally-same-length transfer would pass a size check but fail a hash
    /// comparison). See `FrameMetadataResponse.verifyChecksum(ofFileAt:)`.
    ///
    /// `nil` only for a frame captured before checksum support existed server-side
    /// (INDIMCP-95) — its database row was carried forward by a schema migration with nothing
    /// left to hash. Every frame captured since always has one.
    public let checksumSha256: String?
    public let capturedAt: String
    public let transferredAt: String?

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

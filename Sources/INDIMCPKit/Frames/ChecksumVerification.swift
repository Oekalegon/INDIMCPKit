/// The outcome of comparing a downloaded file's actual content against a frame's
/// `checksumSha256`, from `FrameMetadataResponse.verifyChecksum(ofFileAt:)`.
public enum ChecksumVerification: Sendable, Hashable {
    /// The file's computed SHA-256 matches the server-reported checksum — safe to
    /// `confirmFrameTransfer`.
    case matched
    /// The file's computed SHA-256 (`actual`) doesn't match the server-reported checksum
    /// (`expected`) — the transfer is corrupted or truncated; don't `confirmFrameTransfer`.
    case mismatched(expected: String, actual: String)
    /// This frame has no `checksumSha256` to compare against — it was captured before checksum
    /// support existed server-side (INDIMCP-95). Fall back to a size comparison against
    /// `sizeBytes` instead.
    case noChecksumAvailable
}

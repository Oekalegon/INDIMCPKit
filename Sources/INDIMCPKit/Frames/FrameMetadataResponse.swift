import Foundation

/// `FrameMetadata` plus `downloadUrl` — what `listFrames`/`getFrameMetadata` actually return.
///
/// Mirrors INDIMCP-server's `FrameMetadataResponse` (`server.py`), which subclasses
/// `FrameMetadata` as a Python `TypedDict` — its wire JSON is flat (every `FrameMetadata` field
/// plus `downloadUrl` at the same level), so this is modeled as its own flat struct rather than
/// nesting a `FrameMetadata` inside it, matching how a nested TypedDict would actually decode.
///
/// `downloadUrl` is computed by the server per response from its own current transport/host/port,
/// not stored — `nil` whenever the server has no HTTP listener to build one from (running under
/// the `stdio` transport). `downloadFrame` needs a non-`nil` value to actually fetch the frame's
/// bytes.
public struct FrameMetadataResponse: Codable, Sendable, Hashable {
    public let frameId: String
    public let runId: String?
    public let device: String
    public let sizeBytes: Int
    /// The frame file's SHA-256 checksum, as a lowercase hex string. `nil` only for a frame
    /// captured before checksum support existed server-side — see `FrameMetadata.checksumSha256`,
    /// whose doc comment this mirrors exactly. Compare a downloaded file against this with
    /// `verifyChecksum(ofFileAt:)`.
    public let checksumSha256: String?
    public let capturedAt: String
    public let transferredAt: String?
    public let downloadUrl: String?

    public init(
        frameId: String,
        runId: String?,
        device: String,
        sizeBytes: Int,
        checksumSha256: String?,
        capturedAt: String,
        transferredAt: String?,
        downloadUrl: String?
    ) {
        self.frameId = frameId
        self.runId = runId
        self.device = device
        self.sizeBytes = sizeBytes
        self.checksumSha256 = checksumSha256
        self.capturedAt = capturedAt
        self.transferredAt = transferredAt
        self.downloadUrl = downloadUrl
    }

    /// A reasonable local filename for this frame: `"<device>-<frameId>.fits"`, with any `/` in
    /// `device` replaced by `-` so it can't be misread as a path separator.
    ///
    /// The server never tells a client a frame's original on-disk filename or extension
    /// (deliberately — see `FrameMetadata`'s doc comment), so `.fits` here is a guess, not a fact
    /// recovered from the server; it matches every built-in capture script's own convention. This
    /// is the single owner of that naming scheme — `downloadAllFrames` and
    /// `INDIMCPKitTestApp`'s `FramesModel` both use it, so a frame downloaded through either path
    /// lands under the same name.
    public var suggestedLocalFilename: String {
        let sanitizedDevice = device.replacingOccurrences(of: "/", with: "-")
        return "\(sanitizedDevice)-\(frameId).fits"
    }
}

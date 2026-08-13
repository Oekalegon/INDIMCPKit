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
    public let capturedAt: String
    public let transferredAt: String?
    public let downloadUrl: String?

    public init(
        frameId: String,
        runId: String?,
        device: String,
        sizeBytes: Int,
        capturedAt: String,
        transferredAt: String?,
        downloadUrl: String?
    ) {
        self.frameId = frameId
        self.runId = runId
        self.device = device
        self.sizeBytes = sizeBytes
        self.capturedAt = capturedAt
        self.transferredAt = transferredAt
        self.downloadUrl = downloadUrl
    }
}

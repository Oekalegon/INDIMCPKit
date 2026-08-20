import Foundation

/// `FrameMetadata` plus `downloadUrl`/`issues` — what `listFrames`/`getFrameMetadata` actually
/// return.
///
/// Mirrors INDIMCP-server's `FrameMetadataResponse` (`server.py`), which subclasses
/// `FrameMetadata` as a Python `TypedDict` — its wire JSON is flat (every `FrameMetadata` field
/// plus `downloadUrl`/`issues` at the same level), so this is modeled as its own flat struct
/// rather than nesting a `FrameMetadata` inside it, matching how a nested TypedDict would
/// actually decode.
///
/// `downloadUrl` is computed by the server per response from its own current transport/host/port,
/// not stored — `nil` whenever the server has no HTTP listener to build one from (running under
/// the `stdio` transport). `downloadFrame` needs a non-`nil` value to actually fetch the frame's
/// bytes.
public struct FrameMetadataResponse: Codable, Sendable, Hashable {
    /// The frame's unique, server-assigned identifier.
    public let frameId: String
    /// The script run that captured this frame, if any — `nil` for an ad hoc `capture_frame` call
    /// not made through a script.
    public let runId: String?
    /// The camera device that captured this frame.
    public let device: String
    /// The frame file's size in bytes, as last recorded server-side.
    public let sizeBytes: Int
    /// The frame file's SHA-256 checksum, as a lowercase hex string. `nil` only for a frame
    /// captured before checksum support existed server-side — see `FrameMetadata.checksumSha256`,
    /// whose doc comment this mirrors exactly. Compare a downloaded file against this with
    /// `verifyChecksum(ofFileAt:)`.
    public let checksumSha256: String?
    /// When this frame was captured, as an ISO 8601 timestamp string.
    public let capturedAt: String
    /// When `confirmFrameTransfer` was called for this frame, or `nil` if it hasn't been yet.
    public let transferredAt: String?
    /// A `GET`-able URL for this frame's raw bytes, or `nil` if the server has no HTTP listener
    /// to build one from. `downloadFrame` needs a non-`nil` value to actually fetch the bytes.
    public let downloadUrl: String?
    /// Conditions about this particular frame's metadata worth telling the caller about — always
    /// an array, empty when there's nothing to report, never `nil`.
    ///
    /// Currently only ever contains a `frameChecksumMissing` `.warning` when `checksumSha256` is
    /// `nil` (a frame that predates checksum support server-side), but modeled as the general
    /// `[Issue]` shape the server itself uses rather than a single optional field, since the
    /// server may add more `issues`-worthy conditions here later without changing this type's
    /// shape.
    public let issues: [Issue]

    /// - Parameters:
    ///   - frameId: The frame's unique, server-assigned identifier.
    ///   - runId: The script run that captured this frame, if any — `nil` for an ad hoc
    ///     `capture_frame` call not made through a script.
    ///   - device: The camera device that captured this frame.
    ///   - sizeBytes: The frame file's size in bytes, as last recorded server-side.
    ///   - checksumSha256: The frame file's SHA-256 checksum, or `nil` for a frame that predates
    ///     checksum support server-side.
    ///   - capturedAt: When this frame was captured, as an ISO 8601 timestamp string.
    ///   - transferredAt: When `confirmFrameTransfer` was called for this frame, or `nil` if it
    ///     hasn't been yet.
    ///   - downloadUrl: A `GET`-able URL for this frame's raw bytes, or `nil` if the server has
    ///     no HTTP listener to build one from.
    ///   - issues: Conditions about this frame's metadata worth telling the caller about; `[]`
    ///     when there's nothing to report.
    public init(
        frameId: String,
        runId: String?,
        device: String,
        sizeBytes: Int,
        checksumSha256: String?,
        capturedAt: String,
        transferredAt: String?,
        downloadUrl: String?,
        issues: [Issue]
    ) {
        self.frameId = frameId
        self.runId = runId
        self.device = device
        self.sizeBytes = sizeBytes
        self.checksumSha256 = checksumSha256
        self.capturedAt = capturedAt
        self.transferredAt = transferredAt
        self.downloadUrl = downloadUrl
        self.issues = issues
    }

    private enum CodingKeys: String, CodingKey {
        case frameId, runId, device, sizeBytes, checksumSha256, capturedAt, transferredAt,
            downloadUrl, issues
    }

    /// Decodes from the server's wire JSON, defaulting `issues` to `[]` when the key is absent
    /// entirely — not just when it's explicitly `null`.
    ///
    /// `issues` (INDIMCP-107) was added to `FrameMetadataResponse` after `list_frames`/
    /// `get_frame_metadata` already shipped, so a server instance that hasn't yet been
    /// redeployed past that point (this kit's own version-alignment story allows for some
    /// drift — see `alignedINDIMCPServerVersion`) sends a response with no `"issues"` key at
    /// all, not an empty array. A plain synthesized `Codable` conformance would throw
    /// `keyNotFound` for that response and break `listFrames`/`getFrameMetadata` outright
    /// against any not-yet-upgraded server — the same reason `checksumSha256` is `String?`
    /// rather than a required `String`. This custom decode gives `issues` the same tolerance
    /// without giving up its non-`Optional` "always an array" public shape.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        frameId = try container.decode(String.self, forKey: .frameId)
        runId = try container.decodeIfPresent(String.self, forKey: .runId)
        device = try container.decode(String.self, forKey: .device)
        sizeBytes = try container.decode(Int.self, forKey: .sizeBytes)
        checksumSha256 = try container.decodeIfPresent(String.self, forKey: .checksumSha256)
        capturedAt = try container.decode(String.self, forKey: .capturedAt)
        transferredAt = try container.decodeIfPresent(String.self, forKey: .transferredAt)
        downloadUrl = try container.decodeIfPresent(String.self, forKey: .downloadUrl)
        issues = try container.decodeIfPresent([Issue].self, forKey: .issues) ?? []
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

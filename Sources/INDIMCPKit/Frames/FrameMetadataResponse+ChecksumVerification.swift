import CryptoKit
import Foundation

extension FrameMetadataResponse {
    /// Verifies the file at `url` against this frame's `checksumSha256` by streaming it through
    /// SHA-256 in fixed-size chunks — never buffering the whole file in memory at once, matching
    /// `downloadFrame`'s own reasoning for why a multi-megabyte frame can't be handled any other
    /// way (a whole-file read is exactly the failure mode `downloadFrame`'s streaming download
    /// already avoids on the way in; this avoids the same failure mode on the way back out).
    ///
    /// - Parameter url: The local file to verify, typically the `destination` a prior
    ///   `downloadFrame(_:to:)` call was given.
    /// - Returns: `.matched`/`.mismatched` comparing the file's actual content against
    ///   `checksumSha256`, or `.noChecksumAvailable` if this frame predates checksum support
    ///   server-side (`checksumSha256 == nil`) — the caller should fall back to comparing the
    ///   file's size against `sizeBytes` in that case.
    /// - Throws: Whatever `FileHandle(forReadingFrom:)`/`read(upToCount:)` throws reading `url`
    ///   (e.g. the file doesn't exist, or isn't readable).
    public func verifyChecksum(ofFileAt url: URL) throws -> ChecksumVerification {
        guard let checksumSha256 else { return .noChecksumAvailable }
        let actual = try Self.sha256Hex(ofFileAt: url)
        return actual == checksumSha256 ? .matched : .mismatched(expected: checksumSha256, actual: actual)
    }

    /// Read buffer size for `sha256Hex`: 1 MiB, small enough to never meaningfully spike memory
    /// for a multi-gigabyte frame, large enough to keep the read loop's syscall overhead low.
    private static let chunkSize = 1 << 20

    /// Streams the file at `url` through SHA-256 in `chunkSize` chunks and returns the digest as
    /// lowercase hex.
    private static func sha256Hex(ofFileAt url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: chunkSize), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

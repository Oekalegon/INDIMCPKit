import CryptoKit
import Foundation
import Testing

@testable import INDIMCPKit

/// Pure, offline tests for `FrameMetadataResponse.verifyChecksum(ofFileAt:)` — everything here
/// touches only a local temp file, no network, so none of it needs a live server.

private func makeFrame(checksumSha256: String?) -> FrameMetadataResponse {
    FrameMetadataResponse(
        frameId: "f1", runId: nil, device: "CCD Simulator", sizeBytes: 4,
        checksumSha256: checksumSha256,
        capturedAt: "2026-01-01T00:00:00+00:00", transferredAt: nil, downloadUrl: nil, issues: []
    )
}

private func writeTempFile(_ data: Data) throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    try data.write(to: url)
    return url
}

@Test func verifyChecksumMatchesForIdenticalContent() throws {
    let data = Data("fits-bytes".utf8)
    let checksum = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    let frame = makeFrame(checksumSha256: checksum)
    let url = try writeTempFile(data)

    #expect(try frame.verifyChecksum(ofFileAt: url) == .matched)
}

@Test func verifyChecksumMismatchesForDifferentContent() throws {
    let expected = SHA256.hash(data: Data("original-bytes".utf8)).map { String(format: "%02x", $0) }.joined()
    let frame = makeFrame(checksumSha256: expected)
    let url = try writeTempFile(Data("corrupted-bytes".utf8))

    guard case .mismatched(let actualExpected, let actual) = try frame.verifyChecksum(ofFileAt: url) else {
        Testing.Issue.record("expected .mismatched")
        return
    }
    #expect(actualExpected == expected)
    #expect(actual != expected)
}

@Test func verifyChecksumReportsNoChecksumAvailableForALegacyFrame() throws {
    let frame = makeFrame(checksumSha256: nil)
    let url = try writeTempFile(Data("fits-bytes".utf8))

    #expect(try frame.verifyChecksum(ofFileAt: url) == .noChecksumAvailable)
}

@Test func verifyChecksumMatchesAcrossMultipleChunkBoundaries() throws {
    // Exercises the streaming read loop across more than one 1 MB chunk, not just the
    // single-read path every other test here takes.
    let data = Data(repeating: 0x42, count: (1 << 20) * 2 + 137)
    let checksum = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    let frame = makeFrame(checksumSha256: checksum)
    let url = try writeTempFile(data)

    #expect(try frame.verifyChecksum(ofFileAt: url) == .matched)
}

@Test func verifyChecksumThrowsForAMissingFile() throws {
    let frame = makeFrame(checksumSha256: "abc123")
    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)

    #expect(throws: (any Error).self) {
        try frame.verifyChecksum(ofFileAt: url)
    }
}

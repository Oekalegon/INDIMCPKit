# Frame Checksum Verification

Verify a downloaded frame's bytes against the server-reported SHA-256 before confirming the transfer.

## Overview

Every frame INDIMCP-server captures carries a SHA-256 checksum of its file content
(`checksumSha256`). ``FrameMetadataResponse/verifyChecksum(ofFileAt:)`` compares a locally
downloaded file's actual content against it, returning a ``ChecksumVerification``:

- **`.matched`** — the file's computed SHA-256 equals the server's. Safe to call
  `confirmFrameTransfer`.
- **`.mismatched(expected:actual:)`** — the transfer is corrupted or truncated; don't confirm it.
- **`.noChecksumAvailable`** — this frame predates checksum support (`checksumSha256 == nil`).
  Fall back to comparing the file's size against `sizeBytes` instead.

The check hashes the file incrementally in fixed-size chunks via `FileHandle`, rather than
buffering the whole file in memory — the same streaming discipline `downloadFrame` already applies
on the way in.

## The download → verify → confirm flow

```swift
try await client.downloadFrame(frame, to: destination)

switch try frame.verifyChecksum(ofFileAt: destination) {
case .matched:
    _ = try await client.confirmFrameTransfer(frameId: frame.frameId)
case .mismatched(let expected, let actual):
    // Corrupted or truncated transfer — don't confirm. Consider re-downloading.
case .noChecksumAvailable:
    // Legacy frame — fall back to a size comparison against frame.sizeBytes before confirming.
}
```

The key invariant: **never call `confirmFrameTransfer` before verification passes.** Confirming
tells the server this client has a safe copy, which is what makes a frame eligible for later
deletion — a confirmed-but-actually-corrupted transfer is how a frame's only good copy gets deleted
server-side while the client is left holding bad bytes.

## Why `checksumSha256` can be `nil`

Only for a frame captured before checksum support existed server-side — its database row predates
the column, with no file bytes left to retroactively hash from a migration alone. Every frame
captured since always has one. Treat `nil` as "no checksum to check against," not as an error —
``FrameMetadataResponse/issues`` carries a matching `frameChecksumMissing` warning alongside a
`nil` checksum, explaining exactly why.

For the full design rationale, see
[docs/ChecksumVerification.md](https://github.com/Oekalegon/INDIMCPKit/blob/develop/docs/ChecksumVerification.md)
in the repository.

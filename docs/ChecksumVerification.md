# Frame checksum verification

Every frame INDIMCP-server captures now carries a SHA-256 checksum of its file content
(`checksumSha256`, INDIMCP-95). This document covers what that field is, how INDIMCPKit lets a
client verify a downloaded frame against it, and how that fits into the download → verify →
confirm flow `INDIMCPKitTestApp`'s `FramesModel` already exercises end to end.

## Why this exists

`downloadFrame`/`downloadAllFrames` stream a frame's bytes over plain HTTP. A transfer can fail
partway through — a dropped connection, a truncated read — and land a shorter, corrupted file on
disk without the download call itself necessarily throwing. Before INDIMCP-95, the only
integrity check available client-side was comparing the downloaded file's size against the
server-reported `sizeBytes`. That catches a *truncated* transfer, but not a same-length one with
corrupted bytes in the middle (a bit-flip, a partial retransmit that happened to land the right
byte count) — a real gap, since `confirmFrameTransfer` is what tells the server it's safe to
eventually delete its own copy (`deleteFrame`/`purgeTransferredFrames`). Confirming a corrupted
transfer risks losing the only good copy of that frame.

A real content hash closes that gap: two files with the same SHA-256 are the same bytes, size
match or not.

## The `checksumSha256` field

`FrameMetadata` and `FrameMetadataResponse` both carry:

```swift
public let checksumSha256: String?
```

A lowercase hex string, computed server-side from the frame's actual file bytes at capture time
(`frame_store.save_frame`), and recomputed if the file is later rewritten in place (e.g.
plate-solve's WCS header enrichment, `update_frame_data`).

**It's `nil` for exactly one case:** a frame captured before checksum support existed
server-side. Its database row predates the `checksum_sha256` column and was carried forward by a
schema migration with no file bytes left to retroactively hash from a migration alone. Every
frame captured since INDIMCP-95 always has one. Treat `nil` as "no checksum to check against," not
as an error — and a caller doesn't have to take that on faith: `FrameMetadataResponse.issues`
(INDIMCP-107) carries a matching `frameChecksumMissing` `.warning` `Issue` alongside a `nil`
`checksumSha256`, explaining exactly why, rather than leaving a client to infer it from the field
alone.

`issues` is always an array — empty when there's nothing to report, never `nil` — reusing the same
`Issue`/`Severity` shape already used for `ScriptRunError.warnings`/`ScriptRunCancelled.warnings`
elsewhere in this kit, not a new ad hoc warning type. `INDIMCPKitTestApp`'s `FramesView` shows
these per frame, independent of download
state, since they're about the frame as captured — not about this app's own download/confirm
workflow.

## Verifying a downloaded file

`FrameMetadataResponse.verifyChecksum(ofFileAt:)` compares a local file's actual content against
this field:

```swift
public func verifyChecksum(ofFileAt url: URL) throws -> ChecksumVerification
```

```swift
public enum ChecksumVerification: Sendable, Hashable {
    case matched
    case mismatched(expected: String, actual: String)
    case noChecksumAvailable
}
```

- **`.matched`** — the file's computed SHA-256 equals `checksumSha256`. Safe to call
  `confirmFrameTransfer`.
- **`.mismatched(expected:actual:)`** — it doesn't. The transfer is corrupted or truncated; don't
  confirm it. `expected` is what the server reported, `actual` is what the local file actually
  hashes to — useful to log or show a caller, since they're rarely equal by coincidence.
- **`.noChecksumAvailable`** — this frame predates checksum support (`checksumSha256 == nil`).
  Fall back to comparing the file's size against `sizeBytes` instead, same as every client had to
  do before this existed.

### Why it streams instead of reading the whole file

`downloadFrame`'s own doc comment explains why it streams a frame's bytes straight to disk rather
than buffering them in memory: a multi-megabyte dark frame read entirely into memory is a known
failure mode this server was specifically redesigned around (INDIMCP-89). Hashing a file
naively — `Data(contentsOf: url)` then `SHA256.hash(data:)` — would reintroduce exactly that
problem on the way *out*, after `downloadFrame` already avoided it on the way in.

`verifyChecksum(ofFileAt:)` instead opens the file with `FileHandle` and updates a `SHA256`
hasher incrementally in fixed 1 MB chunks:

```swift
let handle = try FileHandle(forReadingFrom: url)
var hasher = SHA256()
while let chunk = try handle.read(upToCount: chunkSize), !chunk.isEmpty {
    hasher.update(data: chunk)
}
let digest = hasher.finalize()
```

Peak memory use is bounded by the chunk size, not the frame size, regardless of whether the frame
is a few hundred kilobytes or tens of megabytes.

## The full download → verify → confirm flow

This is exactly what `INDIMCPKitTestApp`'s `FramesModel.download(_:)` does, and the shape any
consumer of INDIMCPKit should follow:

```swift
try await client.downloadFrame(frame, to: destination)

switch try frame.verifyChecksum(ofFileAt: destination) {
case .matched:
    _ = try await client.confirmFrameTransfer(frameId: frame.frameId)
case .mismatched(let expected, let actual):
    // Corrupted or truncated transfer — don't confirm. Log/report `expected` vs `actual`,
    // and consider re-downloading.
case .noChecksumAvailable:
    // Legacy frame — fall back to a size comparison against frame.sizeBytes before confirming.
}
```

The key invariant: **never call `confirmFrameTransfer` before verification passes.** Confirming
tells the server this client has a safe copy — that's what makes the frame eligible for
`deleteFrame`/`purgeTransferredFrames` later (see `INDIFrames.swift`'s own doc comments). A
confirmed-but-actually-corrupted transfer is how a frame's only good copy gets deleted server-side
while the client is left holding bad bytes.

## See also

- [`FrameMetadataResponse+ChecksumVerification.swift`](../Sources/INDIMCPKit/Frames/FrameMetadataResponse+ChecksumVerification.swift) — the implementation.
- [`ChecksumVerification.swift`](../Sources/INDIMCPKit/Frames/ChecksumVerification.swift) — the result type.
- [`FramesModel.swift`](../Sources/INDIMCPKitTestApp/FramesModel.swift) — a full working consumer.
- [`ChecksumVerificationTests.swift`](../Tests/INDIMCPKitTests/ChecksumVerificationTests.swift) — matched/mismatched/no-checksum/multi-chunk/missing-file coverage.

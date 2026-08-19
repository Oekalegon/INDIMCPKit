# Frames

Manage captured-frame metadata, download frame bytes, and verify their integrity.

## Overview

A captured exposure is tracked server-side as frame metadata (``FrameMetadataResponse``), separate
from the actual image bytes. ``INDIMCPClient/listFrames(runId:device:since:transferred:)`` lists
it, with `transferred` as a tri-state filter: `nil` for every frame, `true` for ones already
confirmed received, `false` for ones still waiting to be downloaded.

```swift
let pending = try await client.listFrames(transferred: false)
```

## Downloading and confirming

`downloadFrame` streams a frame's raw bytes straight to a local file via the server's
`GET /frames/{frameId}` route, never buffering the whole file in memory. After verifying the
downloaded bytes, call ``INDIMCPClient/confirmFrameTransfer(frameId:)`` — this is what makes a
frame eligible for later deletion, so only confirm a transfer that actually completed
successfully; confirming prematurely risks the server treating its only copy as safe to delete.

``ChecksumVerification`` is how that verification is done: it streams the downloaded file back
through SHA-256 and compares it against the server-reported `checksumSha256`, falling back to a
size comparison only for a frame captured before checksum support existed server-side. See
<doc:ChecksumVerification> for the full flow, and
``FrameMetadataResponse/issues`` for conditions (like a missing checksum) the server wants a
caller to know about for a given frame.

## Cleaning up

Frames are never purged automatically server-side, unlike the durable event log. Deletion is
always explicit:

- ``INDIMCPClient/deleteFrame(frameId:requireTransferred:)`` deletes a single frame — refuses to
  delete an unconfirmed frame unless `requireTransferred` is explicitly set to `false`.
- ``INDIMCPClient/purgeTransferredFrames(olderThanDays:)`` and
  ``INDIMCPClient/deleteAllTransferredFrames()`` bulk-delete already-confirmed frames.
- ``INDIMCPClient/deleteAllFrames(acknowledgingPermanentDataLoss:)`` deletes every frame,
  confirmed or not — its parameter has no default, so it can't be called by accident.

# Event Streams

Subscribe to live INDI messaging and script events, and catch up on what a disconnected client missed.

## Overview

INDIMCP-server exposes two live MCP resources — `indi://messages` and `indi://scripts` — plus a
durable event log for catching up after a gap. INDIMCPKit's ``EventStream`` enumerates both live
resources; ``INDIMCPClient/messageEvents(device:)`` and ``INDIMCPClient/scriptEvents(runId:)``
subscribe to them, each returning an `AsyncThrowingStream` yielded once immediately and again
every time the server notifies the resource changed:

```swift
for try await events in client.messageEvents(device: "CCD Simulator") {
    // events: [IndiEvent], newest first — the resource's current rolling window
}
```

## Live streams are best-effort

These are "notify me while I'm connected" channels, not a resilience mechanism. A client that was
offline should not assume it received every event it missed — there's no per-event identity in
the rolling window to dedupe against either; each yielded array is simply "here's the current
window," which may repeat events already seen. A stream keeps running until its consumer stops
iterating it or an error is thrown.

## Catching up after a reconnect

Use ``INDIMCPClient/getEvents(stream:device:runId:since:)`` against the durable event log instead
— each ``EventRecord`` has a stable `id` to dedupe against, unlike the live streams' rolling
windows. `EventRecord/decodedMessage()` and `EventRecord/decodedScriptStatus()` decode a record's
raw payload into ``IndiEvent`` or ``ScriptRunStatus`` depending on which ``EventStream`` it came
from.

## Keeping a device's properties live

``ObservableMessageStream`` and ``ObservableDevice`` are built on top of `messageEvents` — an
`@Observable` device handle refreshes a full `getDeviceProperties` snapshot on `start()` and
periodically thereafter as a safety net, corrected in between by the live stream. See
<doc:DeviceControl>.

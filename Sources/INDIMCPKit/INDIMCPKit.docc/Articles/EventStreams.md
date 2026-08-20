# Event Streams

Subscribe to live INDI messaging and script events, and catch up on what a disconnected client missed.

## Overview

INDIMCP-server exposes three live MCP resources — `indi://messages`,
`indi://mcp-server/scripts`, and `indi://mcp-server/connection` — plus a durable event log for
catching up after a gap. INDIMCPKit's ``EventStream`` enumerates all three live resources;
``INDIMCPClient/messageEvents(device:)``, ``INDIMCPClient/scriptEvents(runId:)``, and
``INDIMCPClient/connectionEvents(target:)`` subscribe to them, each returning an
`AsyncThrowingStream` yielded once immediately and again every time the server notifies the
resource changed:

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
windows. `EventRecord/decodedMessage()`, `EventRecord/decodedScriptStatus()`, and
`EventRecord/decodedConnectionEvent()` decode a record's raw payload into ``IndiEvent``,
``ScriptRunStatus``, or ``ConnectionEvent`` depending on which ``EventStream`` it came from.

## Connection events

``ConnectionEvent`` tracks connectivity transitions (``ConnectionEventKind/connectionMade``/
``ConnectionEventKind/connectionLost``) for this client's own link to `indiserver`, the
`indiserver` process itself, and individual driver processes — whichever `target` the event names.

## Keeping a device's properties live

``ObservableMessageStream`` and ``ObservableDevice`` are built on top of `messageEvents` — an
`@Observable` device handle refreshes a full `getDeviceProperties` snapshot on `start()` and
periodically thereafter as a safety net, corrected in between by the live stream. See
<doc:DeviceControl>.

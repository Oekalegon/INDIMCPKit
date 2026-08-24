# Live Messaging and Properties

Start the INDI messaging bridge and inspect raw device properties directly.

## Overview

Most of INDIMCPKit works through device-type handles (<doc:DeviceControl>) or event streams
(<doc:EventStreams>), but both are built on a lower layer: INDIMCP-server's INDI messaging bridge,
which connects to `indiserver` and streams its property/message traffic. Several calls
(the connectivity check every device handle runs internally, `startINDIMessaging`-gated event
streams, rig reconciliation) require this bridge to already be running.

```swift
try await client.startINDIMessaging()
let status = try await client.getINDIMessagingStatus()
```

``INDIMCPClient/startINDIMessaging(host:port:)`` connects to `indiserver` and starts streaming its
events — call this once at app startup, before anything that needs live device state.
``INDIMCPClient/getINDIMessagingStatus()`` reports whether the bridge is running and which
host/port it's connected to (``MessagingStatus``). ``INDIMCPClient/stopINDIMessaging()``
disconnects it.

## Reading device state directly

``INDIMCPClient/getDeviceProperties(device:)`` queries `indiserver` directly for a device's full
live property state (``DeviceProperties``) rather than returning a cached reading — check the
returned `refreshed` flag, which is `false` if the driver didn't respond in time and the result
fell back to a cached snapshot instead. This is what device handles like ``Camera/isCoolerOn()``
read their state from directly.

## Sending raw property commands

```swift
try await client.sendINDIProperty(
    device: "Telescope Simulator",
    name: "TELESCOPE_PARK",
    elements: ["PARK": "On"]
)
```

``INDIMCPClient/sendINDIProperty(device:name:elements:)`` is a low-level, unguarded passthrough —
it can set any property on any device, including ones that move hardware, with no confirmation or
state checks. Prefer a device-type abstraction (``Mount``, ``Camera``, ``FilterWheel``,
``Focuser``) whenever one covers what you need; reach for this directly only when you specifically
need to bypass them.

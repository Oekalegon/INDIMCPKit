# Device Control

Drive mount, camera, filter wheel, and focuser hardware through rig-scoped device handles.

## Overview

``Mount``, ``Camera``, ``FilterWheel``, and ``Focuser`` are rig-scoped handles, each conforming to
``DeviceHandle``. Obtain one from an ``INDIMCPClient`` — never construct one directly:

```swift
let mount = client.mount(rigId: "my-rig")
let camera = client.camera(rigId: "my-rig")
```

Every command on a handle first runs a best-effort connectivity check
(`INDIMCPClient.ensureConnected`) before issuing the underlying tool call, so a caller gets an
immediate ``DeviceControlError`` instead of a script run that starts only to fail on its first
step. That check itself needs INDI messaging running server-side
(`INDIMCPClient.startINDIMessaging()`), so a call can also throw `INDIMCPClientError` if messaging
hasn't been started yet.

### Mount

```swift
try await mount.unpark()
try await mount.slew(ra: 5.5, dec: 12.3)
try await mount.setTrackMode("Sidereal")
try await mount.setCustomTrackingRate(raRateArcsecPerSec: 15.0, decRateArcsecPerSec: 0)
try await mount.trackOff()
```

### Camera

```swift
try await camera.coolCamera(targetTempC: -10)
let started = try await camera.captureFrame(exposureSeconds: 30, frameType: .light)
try await camera.coolerOff()
```

`isCoolerOn()` reports the cooler state from the most recently observed live event — see its doc
comment for the staleness caveat inherent to any state derived from
``INDIMCPClient/listINDIMessages(device:limit:)``.

### Filter wheel and focuser

```swift
try await filterWheel.selectFilter("Ha")
try await focuser.setFocusPosition(15000)
```

### Connecting and disconnecting a device

Device handles run a best-effort connectivity check before every command (see above), but a
caller can also drive or inspect connection state directly:

```swift
try await client.connectDevice(rigId: "my-rig", role: "camera")
let connected = try await client.isDeviceConnected(role: .camera, rigId: "my-rig")
try await client.disconnectDevice(rigId: "my-rig", role: "camera")
```

``INDIMCPClient/connectDevice(rigId:role:)`` and ``INDIMCPClient/disconnectDevice(rigId:role:)``
are named that way — not `connect`/`disconnect` — specifically to avoid colliding with
``INDIMCPClient/connect()``/``INDIMCPClient/disconnect()``, which manage the MCP session itself, a
wholly different connection. ``INDIMCPClient/isDeviceConnected(role:rigId:)`` runs the same
best-effort check the device handles use internally, exposed as its own call for UI that wants to
reflect connection state up front rather than only discovering it from a failed command.

### Capture sequences

Beyond a single ``Camera/captureFrame(exposureSeconds:frameType:binningX:binningY:gain:offset:frameX:frameY:frameWidth:frameHeight:locationId:)``
exposure, INDIMCPKit wraps four composed, multi-step scripts that capture a whole sequence of
frames in one call. Unlike the single-action commands above, these have no dedicated server-side
tool of their own — they're reachable only through the generic script mechanism, so they're
`INDIMCPClient` methods rather than being exposed on ``Camera`` directly:

```swift
let started = try await client.captureLightSequence(
    rigId: "my-rig",
    ra: 5.5, dec: 12.3,
    filterName: "Ha",
    focusPosition: 15000,
    exposureSeconds: 300,
    count: 20
)
```

- ``INDIMCPClient/captureLightSequence(rigId:ra:dec:filterName:focusPosition:exposureSeconds:count:objectName:targetTempC:gain:offset:locationId:)``
  — the imaging-session entry point: slews to `ra`/`dec`, selects a filter, moves the focuser,
  cools the camera, then captures `count` light frames.
- ``INDIMCPClient/captureDarkSequence(rigId:exposureSeconds:count:targetTempC:gain:offset:locationId:)`` —
  cools the camera and captures `count` dark frames at a matching exposure length.
- ``INDIMCPClient/captureBiasSequence(rigId:count:exposureSeconds:gain:offset:locationId:)`` — captures
  `count` bias frames back to back, shutter closed.
- ``INDIMCPClient/captureFlatSequence(rigId:filterName:focusPosition:exposureSeconds:count:gain:offset:locationId:)``
  — selects a filter and focus position, then captures `count` flat frames. For sweeping a whole
  grid of flat/dark/bias settings in one run instead, see <doc:CalibrationSweeps>.

Like every device command, each of these returns a ``ScriptRunStarted`` immediately — see
<doc:Scripts> for following the run to completion.

## Every command returns a run, not a result

Every device command returns a ``ScriptRunStarted`` — the underlying operation runs as a script on
the server. See <doc:Scripts> for how to wait for or observe its outcome.

## Keeping state in sync

``ObservableDevice`` wraps any rig-scoped ``DeviceHandle`` role in an `@Observable` type that keeps
its properties live: a full snapshot on `start()` and periodically thereafter, corrected in
between by the live `indi://messages` stream. See <doc:EventStreams>.

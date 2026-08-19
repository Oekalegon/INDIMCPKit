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
```

### Camera

```swift
try await camera.coolCamera(targetTempC: -10)
let started = try await camera.captureFrame(exposureSeconds: 30, frameType: .light)
```

`isCoolerOn()` reports the cooler state from the most recently observed live event — see its doc
comment for the staleness caveat inherent to any state derived from
``INDIMCPClient/listINDIMessages(device:limit:)``.

### Filter wheel and focuser

```swift
try await filterWheel.selectFilter("Ha")
try await focuser.setFocusPosition(15000)
```

## Every command returns a run, not a result

Every device command returns a ``ScriptRunStarted`` — the underlying operation runs as a script on
the server. See <doc:Scripts> for how to wait for or observe its outcome.

## Keeping state in sync

``ObservableDevice`` wraps any rig-scoped ``DeviceHandle`` role in an `@Observable` type that keeps
its properties live: a full snapshot on `start()` and periodically thereafter, corrected in
between by the live `indi://messages` stream. See <doc:EventStreams>.

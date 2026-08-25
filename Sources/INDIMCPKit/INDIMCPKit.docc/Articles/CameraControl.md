# Controlling the Camera

Drive a ``Camera`` end to end: connect, cool it, capture an exposure, and retrieve the frame.

## Overview

This walks through a complete camera session using a rig-scoped ``Camera`` handle: connect a
client, cool the camera to a target temperature, capture a single exposure, then follow the
resulting frame through download, checksum verification, and transfer confirmation. For the
broader device-handle model this builds on, see <doc:DeviceControl>.

## Connect and resolve a camera handle

Every INDIMCPKit call goes through an ``INDIMCPClient``. Connect it, start INDI messaging (the
device handles' connectivity checks and ``Camera/isCoolerOn()`` both depend on it), then resolve
a rig-scoped ``Camera`` handle — devices aren't addressed by name directly; they're reached
through a saved rig's `camera` role:

```swift
let client = INDIMCPClient(endpoint: URL(string: "http://telescope.local:8000/mcp")!)
try await client.connect()
try await client.startINDIMessaging()

let camera = client.camera(rigId: "my-rig")
```

## Cool the camera

Cooling runs as a script on the server, so it returns a ``ScriptRunStarted`` immediately rather
than blocking until the target temperature is reached. Wait for it to finish, then confirm the
cooler switch actually turned on. ``Camera/isCoolerOn()`` reports the most recently observed
`CCD_COOLER` event, so treat `nil` as "unknown," not "off":

```swift
let coolStarted = try await camera.coolCamera(targetTempC: -10)
try await client.waitForTerminalStatus(runId: coolStarted.runId)

let coolerOn = try await camera.isCoolerOn()
print(coolerOn == true ? "Cooler is on" : "Cooler state unknown or off")
```

## Capture a frame

Capture a single exposure with
``Camera/captureFrame(exposureSeconds:frameType:binningX:binningY:gain:offset:frameX:frameY:frameWidth:frameHeight:locationId:)``,
choosing a frame type and, if the camera supports it, a gain/offset pair. Like every device
command, this returns a run to wait on rather than a result — check the terminal status before
assuming a frame was captured, since it can also come back `.failed`, `.cancelled`, or another
non-`.completed` case of ``ScriptRunStatus``:

```swift
let captureStarted = try await camera.captureFrame(
    exposureSeconds: 30,
    frameType: .light,
    gain: 120,
    offset: 30
)
let captureStatus = try await client.waitForTerminalStatus(runId: captureStarted.runId)

guard case .completed(let completed) = captureStatus else {
    // Handle `.failed`, `.cancelled`, or another non-completed `ScriptRunStatus` here.
    fatalError("Capture did not complete: \(captureStatus)")
}
print("Captured \(completed.result.framesCaptured) frame(s)")
```

## Retrieve and verify the frame

A captured exposure is tracked server-side as frame metadata, separate from its image bytes. List
the frames this run produced, download one — `downloadFrame` streams the transfer straight to
disk, never buffering a whole frame in memory — verify its checksum, and only then confirm the
transfer. Confirming an unverified download risks the server treating a corrupted copy as safe to
delete; see <doc:ChecksumVerification> for why:

```swift
let frames = try await client.listFrames(runId: captureStarted.runId)
guard let frame = frames.first else {
    fatalError("No frames found for this run")
}

let destination = URL(fileURLWithPath: "/tmp/\(frame.frameId).fits")
try await client.downloadFrame(frame, to: destination)

switch try frame.verifyChecksum(ofFileAt: destination) {
case .matched:
    _ = try await client.confirmFrameTransfer(frameId: frame.frameId)
case .mismatched(let expected, let actual):
    // Corrupted or truncated transfer — don't confirm. Consider re-downloading.
    print("Checksum mismatch: expected \(expected), got \(actual)")
case .noChecksumAvailable:
    // Legacy frame — fall back to comparing the file's size against frame.sizeBytes.
    break
}
```

# Calibration Sweeps

Capture a full grid of dark, bias, or flat calibration frames in one server-tracked run.

## Overview

A calibration sweep captures once per combination of camera/exposure settings — the cartesian
product of the lists you pass in — as a single server-tracked run, rather than a client driving
many individual `capture_*_sequence` calls by hand. There are two kinds, mirroring the two
calibration-frame families:

- ``INDIMCPClient/runSensorCalibrationSweep(rigId:gains:offsets:flatExposureSecondsList:biasCount:darkCount:biasExposureSeconds:binningX:binningY:frameX:frameY:frameWidth:frameHeight:locationId:)``
  sweeps dark/bias frames — combinations of gain, offset, and exposure length.
- ``INDIMCPClient/runFlatCalibrationSweep(rigId:gains:offsets:exposureSecondsList:filterName:focusPosition:count:binningX:binningY:frameX:frameY:frameWidth:frameHeight:locationId:)``
  sweeps flat frames — the same gain/offset/exposure grid, plus a fixed filter and focus position
  shared across every combination.

Every argument list must be non-empty, and combination order is always gains → offsets →
exposures (outermost to innermost). Like `captureFrame` and the capture-sequence wrappers,
`binningX`/`binningY` (default `1`) and the optional `frameX`/`frameY`/`frameWidth`/`frameHeight`
sub-frame are shared across every combination in the sweep rather than varied per combination.

```swift
let started = try await client.runSensorCalibrationSweep(
    rigId: "my-rig",
    gains: [0, 100],
    offsets: [10],
    flatExposureSecondsList: [30, 60, 120],
    biasCount: 5,
    darkCount: 5
)
```

## Following a sweep

Like a script run, a sweep never blocks until it finishes — a full sweep can run far longer than
any single capture sequence. Poll ``INDIMCPClient/getSensorCalibrationSweepStatus(sweepId:)`` /
``INDIMCPClient/getFlatCalibrationSweepStatus(sweepId:)`` for progress and the eventual terminal
outcome (``SensorCalibrationSweepStatus``/``FlatCalibrationSweepStatus``), or use
``INDIMCPClient/waitForTerminalSweepStatus(sweepId:pollInterval:maxAttempts:)`` /
``INDIMCPClient/waitForTerminalFlatSweepStatus(sweepId:pollInterval:maxAttempts:)`` for the
"start, then wait" shape. ``INDIMCPClient/cancelSensorCalibrationSweep(sweepId:)`` /
``INDIMCPClient/cancelFlatCalibrationSweep(sweepId:)`` stop one early.

- **Sensor sweeps**: `Started` → `Progress` (per combination) → `Completed`, `Failed`, or
  `Cancelled`, each carrying a ``SensorCalibrationSweepCombinationResult`` per finished
  combination.
- **Flat sweeps**: the same shape, with ``FlatCalibrationSweepCombinationResult``.

## Before running a flat sweep

- Important: `runFlatCalibrationSweep` assumes the flat panel (or equivalent light source) is
  already staged in front of the optics — INDIMCP-server has no way to prompt for or verify that,
  and the call starts capturing immediately. Confirming the light source is staged is the caller's
  responsibility, typically via its own human operator, before this is ever invoked.

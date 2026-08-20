# ``INDIMCPKit``

A typed Swift client for an INDIMCP-server instance.

## Overview

[INDIMCP-server](https://github.com/Oekalegon/indi-mcp) exposes an INDI observatory — mount,
camera, filter wheel, focuser, and the `indiserver` process itself — as a set of
[MCP](https://modelcontextprotocol.io) tools: server management, rig/observatory configuration,
script execution, and device control (park/unpark, slew, tracking, cooling, filter selection,
focusing, exposure capture, frame management, and more).

INDIMCPKit wraps that MCP tool surface in a typed, native Swift API so a macOS or iOS app can
drive an INDIMCP-server instance without talking MCP JSON-RPC directly. Every call goes through
``INDIMCPClient``, either directly or via one of the rig-scoped device handles (``Mount``,
``Camera``, ``FilterWheel``, ``Focuser``).

INDIMCPKit models the **standard, built-in tools** that ship with INDIMCP-server. It does not
attempt to statically model arbitrary user-authored scripts a given server instance may have
saved — those are site-specific. It does still support running, listing, and saving them
generically through ``Script`` and the script-run lifecycle types.

## Topics

### Getting started

- <doc:GettingStarted>
- ``INDIMCPClient``

### Device control

- <doc:DeviceControl>
- ``Mount``
- ``Camera``
- ``FilterWheel``
- ``Focuser``
- ``DeviceHandle``
- ``ObservableDevice``
- ``DeviceControlError``
- ``FrameType``
- ``INDIMCPClient/captureLightSequence(rigId:ra:dec:filterName:focusPosition:exposureSeconds:count:objectName:targetTempC:gain:offset:locationId:)``
- ``INDIMCPClient/captureDarkSequence(rigId:exposureSeconds:count:targetTempC:gain:offset:locationId:)``
- ``INDIMCPClient/captureBiasSequence(rigId:count:exposureSeconds:gain:offset:locationId:)``
- ``INDIMCPClient/captureFlatSequence(rigId:filterName:focusPosition:exposureSeconds:count:gain:offset:locationId:)``

### Rigs and observatories

- <doc:RigsAndObservatories>
- ``Rig``
- ``RigSummary``
- ``RigDraft``
- ``RigCheck``
- ``RigSuggestion``
- ``Component``
- ``Role``
- ``FilterAdoptOutcome``
- ``FilterAdoptStatus``
- ``FilterSyncOutcome``
- ``FilterSyncStatus``
- ``FocusRange``
- ``DraftDeviceInfo``
- ``Observatory``
- ``ObservatorySummary``
- ``ObservatoryDraft``
- ``DraftLocationDeviceInfo``

### Script execution

- <doc:Scripts>
- ``Script``
- ``ScriptSummary``
- ``ScriptResult``
- ``Parameter``
- ``ParameterType``
- ``ScriptRunStatus``
- ``ScriptRunStarted``
- ``ScriptRunProgress``
- ``ScriptRunCompleted``
- ``ScriptRunFailed``
- ``ScriptRunCancelled``
- ``ScriptRunPaused``
- ``ScriptRunResumed``
- ``ScriptRunPauseRejected``
- ``ScriptRunError``
- ``PauseOutcome``
- ``ResumeOutcome``

### Calibration sweeps

- <doc:CalibrationSweeps>
- ``FlatCalibrationSweepStatus``
- ``FlatCalibrationSweepStarted``
- ``FlatCalibrationSweepProgress``
- ``FlatCalibrationSweepCompleted``
- ``FlatCalibrationSweepFailed``
- ``FlatCalibrationSweepCancelled``
- ``FlatCalibrationSweepCombinationResult``
- ``SensorCalibrationSweepStatus``
- ``SensorCalibrationSweepStarted``
- ``SensorCalibrationSweepProgress``
- ``SensorCalibrationSweepCompleted``
- ``SensorCalibrationSweepFailed``
- ``SensorCalibrationSweepCancelled``
- ``SensorCalibrationSweepCombinationResult``

### Frame management

- <doc:Frames>
- <doc:ChecksumVerification>
- ``FrameMetadata``
- ``FrameMetadataResponse``
- ``ChecksumVerification``

### Event streams

- <doc:EventStreams>
- ``EventStream``
- ``EventRecord``
- ``ObservableMessageStream``
- ``ConnectionEvent``
- ``ConnectionEventKind``

### Live messaging and properties

- <doc:Messaging>
- ``DeviceProperty``
- ``DeviceProperties``
- ``IndiEvent``
- ``PropertyState``
- ``MessagingStatus``

### Driver and server management

- <doc:ServerAndDriverManagement>
- ``DriverInfo``
- ``DriverStatus``
- ``ServerInfo``
- ``IndiServerStatus``

### Errors

- ``INDIMCPClientError``

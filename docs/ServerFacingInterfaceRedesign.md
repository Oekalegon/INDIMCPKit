# Server-Facing Interface Redesign (IMCPKIT-52)

## Why

Two related but distinct pieces of work, both under this one ticket/doc since they touch the same
handful of files and would likely ship as overlapping PRs anyway:

- **Part 1 — translation layer.** INDIMCP-server currently registers 68 individual MCP tools.
  That's past the point where an LLM client can reliably pick the right one from
  name/description/schema alone, so INDIMCP-113 is consolidating them into ~26 tools, each
  parameterized by a `kind`/`action`/`component` discriminator. The authoritative mapping (old
  tool → new tool/action) lives in the sibling INDIMCP-server repo at `docs/ToolSurfaceRedesign.md`;
  this document doesn't repeat that mapping, it defines how INDIMCPKit's *translation layer*
  absorbs it. INDIMCP-113 states the constraint Part 1 works within: **INDIMCPKit's public
  `Mount`/`Camera`/`FilterWheel`/`Focuser`/`INDIRigs`/etc. API keeps its current EKOS-like shape.**
  `Mount.park()` keeps its signature and behavior — only the internal code that turns that call
  into an MCP `tools/call` request changes, e.g. from calling a dedicated `park` tool to calling
  `mount_action(rig_id, action: "park")`.
- **Part 2 — new device API.** Separately, `Camera`/`FilterWheel` are missing user-facing
  capabilities EKOS's panels already expose — cooler/sensor property get/set, sensor-analysis
  sweeps, per-position filter naming. Unlike Part 1, this genuinely adds new public API — it isn't
  bound by Part 1's "no shape change" constraint, since there's no existing shape to preserve for
  these. (Previously tracked as IMCPKIT-53/51, folded in here.)

## Part 1: Translation layer

### Server-side status (as of 2026-08-24)

INDIMCP-113's server-side redesign is functionally complete. `docs/ToolSurfaceRedesign.md` in the
INDIMCP-server repo is now the authoritative, implemented mapping (not a proposal) — the tables
below are corrected against it and against the real `server.py` signatures, replacing this
document's earlier speculative versions. Merge status, for sequencing INDIMCPKit's own PRs:

| Group | INDIMCP ticket | Status |
|---|---|---|
| INDI infrastructure | INDIMCP-114 | Merged to `develop` |
| Configuration entities | INDIMCP-115 | Merged to `develop` |
| Direct device actions | INDIMCP-116 | Merged to `develop` |
| Script run control | INDIMCP-117 | Merged to `develop` |
| Calibration sweeps | INDIMCP-118 | Merged to `develop` |
| Frames | INDIMCP-120 | Merged to `develop` |
| Plate solving | INDIMCP-119 | Done, on `feature/INDIMCP-119-plate-solving`, not yet merged to `develop` |

Everything INDIMCPKit currently calls is in the merged set — plate solving (the one group still
on a feature branch) isn't wrapped by INDIMCPKit at all today (see below), so its merge status
doesn't block anything here. **INDIMCPKit's translation-layer work can proceed as one effort now**,
not gated group-by-group the way the original rollout plan assumed before the server side existed.

Three corrections to this document's earlier assumptions, each significant enough to call out
before the tables below:

1. **`get_config`/`save_config`/`draft_config` don't exist as separate tools.** They collapsed
   into one tool, `configuration(action: "get"|"save"|"draft", kind, id?, config?, overwrite?)`.
   `list_config` is still its own tool (list is a different shape — no `id`/`config`).
2. **`check_rig`/`suggest_rig` were not left unchanged.** All four of `check_rig`, `suggest_rig`,
   `sync_filter_names`, and `adopt_filter_names_from_driver` merged into one new tool,
   `rig_diagnostics(action: "check"|"suggest"|"sync", rig_id?, role?, direction?)` — a bigger
   consolidation than this document originally assumed (INDIMCP-115).
3. **`list_indi_messages` is dropped, not folded into another tool.** INDIMCP-114 confirmed
   `get_events(stream: "messages", device: ...)` already returns the same data from the durable
   event log, so there's no replacement *tool* — but see the INDI infrastructure section below,
   this is a real behavior migration for INDIMCPKit, not a pure rename.

Also newly available, not previously possible: `camera_action` gained an `abort_exposure` action
(INDIMCP-116) — the old single-purpose tool set never had one, and INDIMCPKit accordingly never
wrapped it. Worth adding to `INDICameraControl.swift`/`Camera` as part of this same effort, since
`camera_action` is being touched anyway.

Plate solving (INDIMCP-119) is new capability INDIMCPKit has never wrapped in any form — out of
scope for this document (a translation-layer effort has nothing to translate there), tracked
separately. One design point worth carrying over if that ticket is picked up: the rig-based case
(what would have been `plate_solve`/`plate_solve_until_precision`) was **dropped as tools
entirely**, not consolidated — it's now `run_script`/`manage_script_run` against a fixed built-in
script id, `plate_solve_rig.yaml`. Only `plate_solve_uploaded_frame` (for a client-supplied FITS
file, unrelated to any rig) and `manage_astrometry_index` remain as dedicated tools.

### Current shape of the translation layer

Every public device/config method in INDIMCPKit already funnels through one of three generic
primitives on `INDIMCPClient` ([INDIMCPClient.swift](../Sources/INDIMCPKit/Client/INDIMCPClient.swift)):
`callTool`, `callToolList`, `callToolUnion`. The extension files under `Sources/INDIMCPKit/*` are
thin, mostly 1:1 wrappers — one public method, one literal tool-name string, e.g.:

```swift
public func park(rigId: String) async throws -> ScriptRunStarted {
    try await callTool("park", arguments: ["rig_id": .string(rigId)], decoding: ScriptRunStarted.self)
}
```

That 1:1-ness is exactly what the redesign collapses. Grepping every `callTool`/`callToolList`/
`callToolUnion` call site turns up 34 distinct tool names currently in use, across these files:

| File | Tool names called |
|---|---|
| `DeviceControl/INDIDeviceConnection.swift` | `connect`, `disconnect` |
| `DeviceControl/INDIMountControl.swift` | `park`, `unpark`, `slew`, `track_off`, `set_track_mode`, `set_custom_tracking_rate` |
| `DeviceControl/INDICameraControl.swift` | `cool_camera`, `cooler_on`, `cooler_off`, `capture_frame` |
| `DeviceControl/INDIFilterWheelControl.swift` | `select_filter` |
| `DeviceControl/INDIFocuserControl.swift` | `set_focus_position` |
| `Rigs/INDIRigs.swift` | `list_rigs`, `get_rig`, `save_rig` |
| `Rigs/INDIRigReconciliation.swift` | `sync_filter_names`, `adopt_filter_names_from_driver` (`check_rig`, `suggest_rig` — unchanged) |
| `Observatories/INDIObservatories.swift` | `get_observatory`, `save_observatory` |
| `Scripts/INDIScripts.swift` | `list_scripts`, `get_script`, `save_script` |
| `Scripts/INDIScriptRuns.swift` | `run_script` (unchanged), `get_script_status`, `cancel_script`, `pause_script`, `resume_script` |
| `CalibrationSweeps/INDISensorCalibrationSweep.swift` | `run_sensor_calibration_sweep`, `get_sensor_calibration_sweep_status`, `cancel_sensor_calibration_sweep` |
| `CalibrationSweeps/INDIFlatCalibrationSweep.swift` | `run_flat_calibration_sweep`, `get_flat_calibration_sweep_status`, `cancel_flat_calibration_sweep` |
| `Frames/INDIFrames.swift` | `list_frames`, `get_frame_metadata`, `confirm_frame_transfer`, `delete_frame`, `purge_transferred_frames` |
| `ServerManagement/INDIServerManagement.swift` | `start_indi_server`, `stop_indi_server`, `restart_indi_server`, `get_indi_server_status` |
| `DriverManagement/INDIDriverManagement.swift` | `list_indi_driver_catalog`, `start_indi_driver`, `stop_indi_driver`, `list_running_indi_drivers` |
| `Messaging/INDIMessaging.swift` | `start_indi_messaging`, `stop_indi_messaging`, `get_indi_messaging_status`, `list_indi_messages`, `get_device_properties`, `send_indi_property` |

(`draft_rig`/`draft_observatory` and `get_events`/`get_server_info` also exist as tools; the
former two aren't currently wrapped by an INDIMCPKit method, and the latter two are already
unchanged in the redesign.)

Note that INDIMCPKit doesn't yet wrap plate-solving or `abort_exposure` — see "Server-side status"
above for both.

### What changes: per-group mapping

Using INDIMCP-113's tool inventory, restricted to tools INDIMCPKit actually calls today:

#### Direct device actions (highest-traffic, safety-sensitive)

| File | Old tool(s) | New call |
|---|---|---|
| `INDIDeviceConnection.swift` | `connect`, `disconnect` | `set_connection(rig_id, role, connected: Bool)` |
| `INDIMountControl.swift` | `park`, `unpark`, `slew`, `track_off`, `set_track_mode`, `set_custom_tracking_rate` | `mount_action(rig_id, action, ...)` |
| `INDICameraControl.swift` | `cool_camera`, `cooler_on`, `cooler_off`, `capture_frame` | `camera_action(rig_id, action: "cool"\|"cooler_on"\|"cooler_off"\|"capture_frame", ...)` — note the action is `"cool"`, not `"cool_camera"` |
| `INDICameraControl.swift` | *(none — new)* | `camera_action(rig_id, action: "abort_exposure")` — no old tool existed; add `Camera.abortExposure()` while this file is being touched anyway |
| `INDIFilterWheelControl.swift` | `select_filter` | `filter_wheel_action(rig_id, action: "select", filterName)` |
| `INDIFocuserControl.swift` | `set_focus_position` | `focuser_action(rig_id, action: "set_position", position)` |

#### Configuration entities (rig / observatory / script)

`list_rigs`/`list_observatories`/`list_scripts` collapse into `list_config(kind)`, unchanged from
this document's original assumption. Everything else collapses differently than assumed — into
**two** tools, not per-entity CRUD tools: `configuration` (the CRUD-shaped operations) and
`rig_diagnostics` (rig-only, diagnostic/reconciliation operations) — see "Server-side status"
above for why the wider `check`/`suggest`/`sync`/`run` merge was rejected in favor of this split.

| File | Old tool(s) | New call |
|---|---|---|
| `INDIRigs.swift` | `list_rigs` | `list_config(kind: "rig")` |
| `INDIRigs.swift` | `get_rig`, `save_rig` | `configuration(action: "get"\|"save", kind: "rig", id?, config?, overwrite?)` |
| `INDIRigReconciliation.swift` | `check_rig` | `rig_diagnostics(action: "check", rig_id)` |
| `INDIRigReconciliation.swift` | `suggest_rig` | `rig_diagnostics(action: "suggest")` — takes no `rig_id`/`role`/`direction` |
| `INDIRigReconciliation.swift` | `sync_filter_names`, `adopt_filter_names_from_driver` | `rig_diagnostics(action: "sync", rig_id, role, direction: "to_driver"\|"from_driver")` |
| `INDIObservatories.swift` | `get_observatory`, `save_observatory` | `configuration(action: "get"\|"save", kind: "observatory", id?, config?, overwrite?)` |
| `INDIScripts.swift` | `list_scripts` | `list_config(kind: "script")` |
| `INDIScripts.swift` | `get_script`, `save_script` | `configuration(action: "get"\|"save", kind: "script", id?, config?, overwrite?)` |

(`draft_rig`/`draft_observatory`, not currently wrapped, would map to `configuration(action:
"draft", kind: "rig"|"observatory")` whenever INDIMCPKit wraps them — no `kind: "script"` for
`draft`, the server rejects that combination.)

Since `INDIRigs.swift` and `INDIRigReconciliation.swift` now target two different consolidated
tools rather than one each, they likely want two separate private helpers (`configurationTool`/
`rigDiagnosticsTool`, or similar) rather than one shared one — see "Design of the translation
layer" below.

#### Script run control

| File | Old tool(s) | New call |
|---|---|---|
| `INDIScriptRuns.swift` | `get_script_status`, `cancel_script`, `pause_script`, `resume_script` | `manage_script_run(run_id, action: "status"\|"cancel"\|"pause"\|"resume")` — `run_script` itself is unchanged |

#### Calibration sweeps

| File | Old tool(s) | New call |
|---|---|---|
| `INDISensorCalibrationSweep.swift` | `run_sensor_calibration_sweep`, `get_sensor_calibration_sweep_status`, `cancel_sensor_calibration_sweep` | `run_calibration_sweep(kind: "sensor", rig_id, ...)`, `manage_calibration_sweep(sweep_id, action: "status"\|"cancel")` |
| `INDIFlatCalibrationSweep.swift` | `run_flat_calibration_sweep`, `get_flat_calibration_sweep_status`, `cancel_flat_calibration_sweep` | same tools, `kind: "flat"` |

#### Frames

| File | Old tool(s) | New call |
|---|---|---|
| `INDIFrames.swift` | `list_frames`, `get_frame_metadata` | `frames(action: "list"\|"get", ...)` |
| `INDIFrames.swift` | `confirm_frame_transfer`, `delete_frame`, `purge_transferred_frames` | `manage_frame(action: "confirm_transfer"\|"delete"\|"purge", ...)` |

#### INDI infrastructure

| File | Old tool(s) | New call |
|---|---|---|
| `ServerManagement/INDIServerManagement.swift` | `start_indi_server`, `stop_indi_server`, `restart_indi_server` | `manage_indi_infra(component: "server", action: "start"\|"stop"\|"restart", port?)` |
| `ServerManagement/INDIServerManagement.swift` | `get_indi_server_status` | `get_indi_status(component: "server")` |
| `DriverManagement/INDIDriverManagement.swift` | `start_indi_driver`, `stop_indi_driver` | `manage_indi_infra(component: "driver", action: "start"\|"stop", label)` |
| `DriverManagement/INDIDriverManagement.swift` | `list_indi_driver_catalog`, `list_running_indi_drivers` | `list_indi_drivers(scope: "catalog"\|"running")` |
| `Messaging/INDIMessaging.swift` | `start_indi_messaging`, `stop_indi_messaging` | `manage_indi_infra(component: "messaging", action: "start"\|"stop", host?, port?)` |
| `Messaging/INDIMessaging.swift` | `get_indi_messaging_status` | `get_indi_status(component: "messaging")` |
| `Messaging/INDIMessaging.swift` | `get_device_properties`, `send_indi_property` | `indi_property(action: "get"\|"set", device, name?, elements?)` |
| `Messaging/INDIMessaging.swift` | `list_indi_messages` | **no replacement tool** — see below |

`get_server_info` is unchanged and needs no translation-layer change.

**`list_indi_messages` needs a real migration, not a retarget.** INDIMCP-114 confirmed
`get_events(stream: "messages", device: ...)` (already an unchanged tool INDIMCPKit already wraps
as `getEvents(stream:device:runId:target:since:)` in `EventStreams/INDIMCPClient+EventLog.swift`)
returns the same underlying data, and dropped `list_indi_messages` with no replacement rather than
folding it into anything. But the two aren't a drop-in swap for `listINDIMessages`'s callers:

- `getEvents` returns `[EventRecord]` (a `kind`-tagged envelope with log metadata — `id`,
  `occurredAt`, ...), not `[IndiEvent]` directly. A caller needs `.decodedMessage()` per record to
  get the `IndiEvent` `listINDIMessages` returned directly.
- `getEvents` has no `limit` parameter — `listINDIMessages(device:limit:)`'s `limit` has no
  equivalent; `getEvents` paginates via `since` (an `occurredAt` cursor) instead.
- `getEvents` returns oldest-first; `listINDIMessages` returned newest-first. A caller relying on
  the old ordering (see below) needs to reverse it or change its own search direction.

`Camera.isCoolerOn()` ([Devices/Camera.swift](../Sources/INDIMCPKit/Devices/Camera.swift)) is the
one real caller today, and depends on exactly the two things that don't carry over: it calls
`listINDIMessages(device:limit:)` with three widening `limit`s (20/100/500) to find the most
recent `CCD_COOLER` event, relying on newest-first order to make `.first(where:)` correct. Moving
this onto `getEvents` isn't optional once `list_indi_messages` is gone — this is the forcing
function for IMCPKIT-28 (*"Derive Camera isConnected/isCoolerOn from live ObservableDevice
properties"*, already backlogged, referenced in Part 2 above), which proposes reading `CCD_COOLER`
directly via `getDeviceProperties`/`indi_property` instead — no event-log paging, ordering, or
`limit`-widening involved at all. Do IMCPKIT-28 as part of this migration rather than reimplementing
`isCoolerOn`'s current event-scan against `getEvents`, since the direct-property-read version sidesteps
every one of the three gaps above rather than working around each of them.

### Design of the translation layer

Two ways to land this in Swift, both preserving the public API:

**A. Inline the new tool name/arguments into each existing method body.** Minimal diff per file;
each group above becomes an independent, small PR — matches INDIMCP-113's note that groups are
independently shippable.

**B. Add one private per-group helper that all of a file's public methods funnel through**, e.g.
in `INDIMountControl.swift`:

```swift
private func mountAction(
    rigId: String,
    action: String,
    extra: [String: Value] = [:]
) async throws -> ScriptRunStarted {
    var arguments: [String: Value] = ["rig_id": .string(rigId), "action": .string(action)]
    arguments.merge(extra) { _, new in new }
    return try await callTool("mount_action", arguments: arguments, decoding: ScriptRunStarted.self)
}
```

**Recommendation: B.** Every verb in a group shares the same `rig_id`/`action` envelope; inlining
it six times per file (once per group) reroutes the same duplication the server-side redesign is
explicitly trying to eliminate, just onto the client. A private `enum` per group for the action
string (e.g. `private enum MountAction: String { case park, unpark, slew, trackOff, setTrackMode,
setCustomTrackingRate }`) is worth adding alongside the helper — internal-only, so it doesn't
touch the public surface, but it turns a typo'd action string into a compile error instead of a
runtime `toolCallFailed`.

This is a mechanical, per-group change: each of the tables above becomes one such helper plus
updated bodies in its file, with no change to any file outside `Sources/INDIMCPKit/*` (no
`Devices/Mount.swift` etc. changes — those already only call the `INDIMCPClient` extension
methods by name, never the tool string directly). One adjustment from the original version of
this section: `Rigs/INDIRigs.swift` and `Rigs/INDIRigReconciliation.swift` each need their *own*
helper now (`configurationTool`/`rigDiagnosticsTool` or similar) rather than sharing one, since
they target two different consolidated tools (`configuration` vs. `rig_diagnostics`) — they're no
longer the "one file, one new tool" shape every other group is.

### Rollout plan

Server-side, every group INDIMCPKit calls today is already merged (see "Server-side status"
above) — this is no longer gated group-by-group the way it was when this document was first
written, before the server side existed. The groups below remain a sensible *order* for INDIMCPKit's
own PRs (risk/traffic-ascending, infra first since it's easiest to validate against the test app's
Server tab), but nothing blocks starting any of them, or combining several into fewer PRs, purely
based on server readiness:

1. **INDI infrastructure** — `manage_indi_infra`, `get_indi_status`, `list_indi_drivers`,
   `indi_property`, plus the `list_indi_messages` → `getEvents`/IMCPKIT-28 migration above. Low
   blast radius, already exercised by `INDIMCPKitTestApp`'s Server tab.
2. **Direct device actions** — `mount_action`/`camera_action` (incl. the new `abort_exposure`
   action)/`filter_wheel_action`/`focuser_action`/`set_connection`. Highest traffic and touches
   real hardware; do this once the pattern from (1) is validated.
3. **Configuration entities** — `list_config`/`configuration`/`rig_diagnostics`. Note this group
   now needs two helpers per the note above, not one.
4. **Script run control** — `manage_script_run`.
5. **Calibration sweeps** — `run_calibration_sweep`/`manage_calibration_sweep`.
6. **Frames** — `frames`/`manage_frame`.

(No separate "Events" step — `get_events`/`get_server_info` were already unchanged tools, and
`list_indi_messages`'s migration is folded into step 1 above, not its own step.)

### Testing

INDIMCPKit's `*IntegrationTests` (e.g. `INDIDeviceControlIntegrationTests`,
`INDIScriptRunsIntegrationTests`) run against a live INDIMCP-server instance
(`IndiServerTestLock.swift` serializes access to it), not a mock transport. That means:

- No public-API test changes are expected — the tests call `Mount.park()` etc., not tool names
  directly, so behavior/assertions stay the same.
- The test server needs to be running INDIMCP-server's `develop` branch (or later) for every
  group except plate solving (irrelevant here, INDIMCPKit doesn't wrap it) — all groups
  INDIMCPKit touches are already merged there, so this is no longer a blocker to sequence around,
  just a prerequisite to check once per test run.
- Smoke-test the affected `INDIMCPKitTestApp` screen by hand (per this project's usual
  UI-verification practice) after each group, since the automated tests don't cover the SwiftUI
  layer.

## Part 2: New Camera & FilterWheel device API

`Camera` today is fire-and-forget: `coolCamera`/`coolerOn`/`coolerOff`/`captureFrame`/the
capture-sequence wrappers, plus one bespoke read (`isCoolerOn`). EKOS's camera panel exposes a lot
more as live, individually get/settable properties — current/target cooler temp, cooler power,
gain, offset, binning, ROI, bit depth, filter, frame type, exposure countdown. `FilterWheel` is
similarly thin: `selectFilter` (set, by name) is its only method. This part designs the missing
get/set surface on both, plus a `Camera`-scoped sensor-analysis wrapper, grounded in what
INDIMCP-server actually exposes today — not assumed from EKOS or the generic INDI spec.

Unlike Part 1, this touches `Devices/Camera.swift`, `Devices/FilterWheel.swift`,
`DeviceControl/INDICameraControl.swift`, and `Rigs/INDIRigReconciliation.swift` with genuinely new
methods, not retargeted ones — expect real diffs there, not mechanical renames.

### What already exists (no new work)

| Requested capability | Existing coverage |
|---|---|
| Cooler On/Off | `Camera.coolerOn()`/`coolerOff()`/`isCoolerOn()` |
| Gain (set) | `captureFrame(gain:)`, and the four capture-sequence wrappers |
| Offset (set) | `captureFrame(offset:)`, ditto |
| Binning (set) | `captureFrame(binningX:binningY:)` |
| Frame ROI (set) | `captureFrame(frameX:frameY:frameWidth:frameHeight:)` |
| Type (Light/Dark/Bias/Flat) | `captureFrame(frameType:)` (`FrameType` enum); the four sequence wrappers each fix their own type implicitly |
| Number of exposures in sequence | `count` on `captureDarkSequence`/`captureBiasSequence`/`captureFlatSequence`/`captureLightSequence` |
| Object name | `captureLightSequence(objectName:)` — Light-only, matching `OBJECT`'s FITS-header rule (see `docs/FitsHeaders.md` in INDIMCP-server: only written for `Light` frames when supplied) |
| Filter (set, by name) | `FilterWheel.selectFilter(_:)` |
| Filter slot-name config (bulk push/pull) | `INDIMCPClient.syncFilterNames`/`adoptFilterNamesFromDriver` — see the FilterWheel section below for why these aren't wrapped on `FilterWheel` yet either |

All of these are *set-only* today (or, for gain/offset/binning/frame/type, only settable as part
of one atomic `captureFrame` call, not as standing camera state). Everything below is either a
missing **get**, or a **set** that should exist independent of triggering an exposure.

### Grounding: what INDI properties actually back these

Confirmed against INDIMCP-server's own source (`indi_messaging.py`, `rig_store.py`,
`server.py`), not assumed:

| Concept | INDI property | Element(s) | Notes |
|---|---|---|---|
| Cooler switch | `CCD_COOLER` | `COOLER_ON` | Already used by `isCoolerOn()` |
| Temperature | `CCD_TEMPERATURE` | `CCD_TEMPERATURE_VALUE` | **One property, not two** — see caveat below |
| Exposure | `CCD_EXPOSURE` | `CCD_EXPOSURE_VALUE` | Counts down live while an exposure runs |
| Binning | `CCD_BINNING` | `HOR_BIN`, `VER_BIN` | |
| Frame ROI | `CCD_FRAME` | (X/Y/WIDTH/HEIGHT — element names not yet confirmed, likely match INDI's standard `X`/`Y`/`WIDTH`/`HEIGHT`) | |
| Frame type | `CCD_FRAME_TYPE` | — | |
| Gain | `CCD_GAIN` | `GAIN` | |
| Offset | `CCD_OFFSET` | `OFFSET` | |
| Static sensor info | `CCD_INFO` | `CCD_MAX_X`, `CCD_MAX_Y`, `CCD_PIXEL_SIZE`, `CCD_BITSPERPIXEL` | Read-only; already parsed by `rig_store.draft_rig` for `DraftDeviceInfo` |
| Filter slot (on a filter wheel device) | `FILTER_SLOT`, `FILTER_NAME` | `FILTER_SLOT_VALUE`, `FILTER_SLOT_NAME_<n>` | |

Not found anywhere in INDIMCP-server's code — meaning nothing server-side names them explicitly,
but see the next section for why that doesn't block reading them:

- **Cooler power** (`CCD_COOLER_POWER`, standard INDI property on cameras that report it)
- **Capture/transfer format** (`CCD_CAPTURE_FORMAT` — only some drivers support switching this)

#### Why "get" doesn't need new server tools

`getDeviceProperties(device:)` (→ `get_device_properties` → the consolidated `indi_property`
tool, Part 1) is a **generic passthrough** to whatever `indiserver` reports for that device — it
isn't limited to properties `server.py` happens to name. So every read in the table above,
including `CCD_COOLER_POWER` if a given driver exposes it, is already reachable with zero
server-side changes; the gap is purely a missing typed Swift accessor.

#### Why some "sets" do need a decision, not just new server tools

`sendINDIProperty(device:name:elements:)` (→ `send_indi_property`, also a generic passthrough) can
already write any of `CCD_GAIN`/`CCD_OFFSET`/`CCD_BINNING`/`CCD_FRAME`/`CCD_TEMPERATURE` directly,
completely independent of `capture_frame`. The design question isn't "can we", it's whether
INDIMCPKit should:

- **(A)** expose these as raw property writes (thin wrappers over `sendINDIProperty`, no script
  run, no `ScriptRunStarted` to poll — returns once the driver acknowledges the property), or
- **(B)** route them through the same connectivity-checked, `DeviceControlError`-raising path
  every other `Camera` method uses.

**Recommendation: (B)**, for consistency — every other `Camera` method pre-checks connectivity via
`ensureConnected` and raises `DeviceControlError` up front rather than surfacing a raw
`INDIMCPClientError` from a failed property send. The new setters should do the same, just calling
`sendINDIProperty` instead of a script tool underneath (no script run needed for a single property
write, so these return the new property state directly, not a `ScriptRunStarted`).

### Proposed Camera API

```swift
extension Camera {
    // MARK: Cooler

    /// Current sensor temperature, in Celsius — `nil` if not yet observed.
    public func currentTempC() async throws -> Double?

    /// The temperature the cooler is currently driving toward. Caveat: INDI's `CCD_TEMPERATURE`
    /// carries only one value — the driver doesn't separately report "requested" vs. "actual",
    /// so between a `setTargetTempC`/`coolCamera` call and the sensor settling, this reads the
    /// same live, still-changing value as `currentTempC()`. Kept as a distinct method (rather
    /// than documented as an alias) so call sites read as intent, and so this can be corrected
    /// transparently if a driver-specific target readback ever becomes available.
    public func targetTempC() async throws -> Double?

    /// Sets the cooler's target temperature without waiting for it to stabilize — unlike
    /// `coolCamera`, which blocks until settled. Returns once the driver acknowledges the new
    /// setpoint.
    public func setTargetTempC(_ targetTempC: Double) async throws

    /// Cooler power, 0–100 (percent) — `nil` if this driver doesn't report `CCD_COOLER_POWER`.
    public func coolerPowerPercent() async throws -> Double?

    // MARK: Exposure

    /// Seconds remaining on the exposure currently in progress — `0` if none is running, `nil`
    /// if that can't be determined (mirrors `isCoolerOn`'s `nil` case).
    public func exposureCountdownSeconds() async throws -> Double?

    // MARK: Sensor settings (standing state, independent of any one captureFrame call)

    public func gain() async throws -> Double?
    public func setGain(_ gain: Double) async throws

    public func offset() async throws -> Double?
    public func setOffset(_ offset: Double) async throws

    public func binning() async throws -> (x: Int, y: Int)?
    public func setBinning(x: Int, y: Int) async throws

    public func frame() async throws -> (x: Int, y: Int, width: Int, height: Int)?
    public func setFrame(x: Int, y: Int, width: Int, height: Int) async throws

    /// Bit depth the sensor reports, from static `CCD_INFO` — read-only. No `set`: only some
    /// CMOS drivers support switching capture format at all (`CCD_CAPTURE_FORMAT`), and
    /// INDIMCP-server doesn't currently wrap it. Revisit if a concrete camera needs it.
    public func bitDepth() async throws -> Int?
}
```

Each getter follows `isCoolerOn`'s existing shape — resolve the rig's device name, read via
`getDeviceProperties`, pull the element, return `nil` on anything not yet observable — rather than
`isCoolerOn`'s `listINDIMessages` event-log scan, since a direct property read is simpler and
already the pattern `ObservableDevice.refreshSnapshot` uses. (IMCPKIT-28, *"Derive Camera
isConnected/isCoolerOn from live ObservableDevice properties"*, is tracking moving `isCoolerOn`
itself onto this same direct-read shape — do that alongside this work rather than duplicating two
different read strategies across `Camera`.)

### Sensor analysis controls

Separate from get/set properties: running a sensor-analysis (PTC-style gain/read-noise/full-well)
sweep — bias + flat-dark frames captured across a cartesian product of `(gain, offset,
flatExposureSeconds)` combinations. INDIMCP-server already has this as its own tool family
(`run_sensor_calibration_sweep`/`get_sensor_calibration_sweep_status`/
`cancel_sensor_calibration_sweep` — becoming `run_calibration_sweep`/`manage_calibration_sweep`
under Part 1 above), and INDIMCPKit already wraps all three at the `INDIMCPClient` level
(`Sources/INDIMCPKit/CalibrationSweeps/INDISensorCalibrationSweep.swift`:
`runSensorCalibrationSweep`/`getSensorCalibrationSweepStatus`/`cancelSensorCalibrationSweep`/
`waitForTerminalSweepStatus`). What's missing is exactly what IMCPKIT-45 already added for plain
captures (`captureDarkSequence`, `captureBiasSequence`, ...): a `Camera`-scoped wrapper that
pre-checks connectivity and drops the now-redundant `rigId` parameter, matching every other
`Camera` method's shape.

```swift
extension Camera {
    /// Runs a bias + flat-dark sensor-analysis sweep across every `(gain, offset,
    /// flatExposureSeconds)` combination. See `INDIMCPClient.runSensorCalibrationSweep` for the
    /// full parameter set and combination-ordering rules.
    public func runSensorCalibrationSweep(
        gains: [Double],
        offsets: [Double],
        flatExposureSecondsList: [Double],
        biasCount: Int,
        darkCount: Int,
        biasExposureSeconds: Double = 0,
        locationId: String? = nil
    ) async throws -> SensorCalibrationSweepStarted {
        try await client.ensureConnected(role: .camera, rigId: rigId)
        return try await client.runSensorCalibrationSweep(
            rigId: rigId,
            gains: gains,
            offsets: offsets,
            flatExposureSecondsList: flatExposureSecondsList,
            biasCount: biasCount,
            darkCount: darkCount,
            biasExposureSeconds: biasExposureSeconds,
            locationId: locationId
        )
    }
}
```

`getSensorCalibrationSweepStatus(sweepId:)`/`cancelSensorCalibrationSweep(sweepId:)`/
`waitForTerminalSweepStatus(sweepId:)` are **not** re-wrapped on `Camera`: they take a `sweepId`,
not a `rigId`, so there's no rig-scoped connectivity check to add and no `rigId` boilerplate to
drop — calling straight through to the existing `INDIMCPClient` methods (exactly like
`waitForTerminalStatus(runId:)` for plain script runs, which `Camera`/`Mount`/etc. don't re-wrap
either) is already the right shape. Only the *start* call benefits from a `Camera`-scoped version.

The flat-sweep half (`INDIFlatCalibrationSweep.swift` / `run_flat_calibration_sweep`) is explicitly
out of scope per that file's own doc comment ("the flat side is a separate sweep, IMCPKIT-33") —
leave it out of this ticket and track it as its own follow-up if the same `Camera`-wrapper gap
applies there too.

### FilterWheel: current filter + per-position naming

Two distinct gaps, grounded in `FILTER_SLOT`/`FILTER_NAME` and the rig's own `Component.slots`
(`Rigs/Component.swift`) — already confirmed against INDIMCP-server's source
(`script_engine.py`, `rig_store.py`):

1. **Get the currently selected filter.** `selectFilter` (set) already exists;
   there's no getter. The live property is `FILTER_SLOT`'s `FILTER_SLOT_VALUE` element (a slot
   number), resolved to a name via the rig's configured `slots` map — exactly what
   `script_engine.py`'s `_current_filter_name` already does server-side for FITS-header purposes.
2. **Get/set each position's configured name** — e.g. "slot 3 is Ha", independent of which filter
   is currently selected. This is `Component.slots: [Int: String]`, the rig's *configured* map —
   already a full round-trip citizen of `Rig`/`saveRig`, but with no `FilterWheel`-scoped
   convenience to read or patch a single slot, and two already-built reconciliation tools
   (`syncFilterNames`/`adoptFilterNamesFromDriver`) that aren't wrapped on `FilterWheel` either —
   same "exists on `INDIMCPClient`, missing on the device handle" shape as the sensor sweep above.
3. **How many slots the wheel has.** No dedicated INDI "count" property exists — INDIMCP-server
   itself derives this as `len()` of whichever slots map it's looking at (rig-configured or live
   `FILTER_NAME`), so there are genuinely two possible counts, not one: `filterNames().count`
   (what the rig is configured for) vs. the live driver's actual count, which the rig might not
   know yet (e.g. before this filter wheel has ever been configured at all). `liveFilterNames()`
   below answers the live one.

Important distinction carried over from the existing `syncFilterNames`/`adoptFilterNamesFromDriver`
design: the rig's configured `slots` (in the saved rig YAML) and the driver's live `FILTER_NAME`
are two independent stores that can disagree, and nothing in this kit pushes one to the other
except those two tools, deliberately, on request. `setFilterName` below only ever touches the
*rig's* configured name — same as everywhere else in this kit, a live hardware write is never a
side effect of a config change; call `syncFilterNames()` afterward if the driver should adopt it.

```swift
extension FilterWheel {
    /// The name of the currently selected filter, per the rig's configured slot map — `nil` if
    /// undetermined (no `FILTER_SLOT` observed yet, or the live slot isn't in the rig's `slots`
    /// map). Read-side counterpart to `selectFilter`.
    public func currentFilterName() async throws -> String?

    /// The rig's configured slot-number → filter-name map for this filter wheel — the "source of
    /// truth" independent of whatever the driver currently reports live. Convenience over
    /// `client.getRig(id:)`'s matching component. `.count` is the *configured* slot count.
    public func filterNames() async throws -> [Int: String]

    /// The filter wheel's live slot-number → filter-name map, read directly from the connected
    /// driver's `FILTER_NAME` property — independent of the rig's configured `slots` (which may
    /// not exist yet, e.g. before this filter wheel has ever been configured, or may disagree with
    /// the driver). Empty if the device hasn't reported `FILTER_NAME` yet.
    ///
    /// `.count` is the number of positions the connected filter wheel actually reports — the
    /// answer to "how many slots does this filter wheel have", independent of naming. Same
    /// primitive `syncFilterNames`/`adoptFilterNamesFromDriver` already use server-side
    /// (`len(live_slots)` in `script_engine.py`) to detect a slot-count mismatch.
    public func liveFilterNames() async throws -> [Int: String]

    /// Sets (or renames) filter position `slot`'s name in the rig's saved configuration, via
    /// `saveRig(overwrite: true)`. Does **not** push the change to the live driver — see
    /// `syncFilterNames()` for that, a deliberate, separate step.
    ///
    /// - Returns: The filter wheel's full slot map after the change.
    /// - Throws: `DeviceControlError.noComponentForRole` if the rig has no `filterWheel`-role
    ///   component.
    public func setFilterName(slot: Int, name: String) async throws -> [Int: String]

    /// Pushes the rig's configured filter names to the driver's live `FILTER_NAME`, if they
    /// disagree. Thin wrapper dropping the redundant `rigId`/`role` from
    /// `INDIMCPClient.syncFilterNames`.
    public func syncFilterNames() async throws -> FilterSyncOutcome

    /// Copies the driver's live `FILTER_NAME` onto the rig, overwriting whatever filter slots the
    /// rig currently declares. Thin wrapper over `INDIMCPClient.adoptFilterNamesFromDriver`.
    public func adoptFilterNamesFromDriver() async throws -> FilterAdoptOutcome
}
```

`syncFilterNames()`/`adoptFilterNamesFromDriver()` are pure pass-throughs once `rigId`/`role` are
dropped — no new logic, same shape as the sensor-sweep wrapper above. `liveFilterNames()` and
`setFilterName` are the ones with real implementation work:

- `liveFilterNames()` reads `getDeviceProperties(device:).properties["FILTER_NAME"]?.elements` and
  parses each `FILTER_SLOT_NAME_<n>` key into `{n: value}` — the same parse `rig_store.py`'s
  `_parse_filter_name_slots` already does server-side (confirmed at `rig_store.py:543`). Worth
  porting that exact parsing logic 1:1 rather than re-deriving it, since it's already
  battle-tested against real driver output.

- `Component`/`Rig` are all-`let` value types with no copy-with helper today — mutating one
  component's `slots` inside a rig means reconstructing both the `Component` (14 stored
  properties) and the `Rig` around it via their memberwise `init`s. Worth adding a small
  `Component.withSlots(_:)` (or a generic copy-with) rather than hand-copying every field at each
  call site — a new `Component` field added later would otherwise silently not get carried over
  wherever this pattern gets hand-rolled.
- **Multiple filter wheels on one rig.** `Component.id` is documented as unique per role being
  possible (e.g. two guide cameras) — the same could apply to `filterWheel`. `setFilterName`/
  `filterNames` need to pick *which* filter-wheel component's `slots` to read/patch. The existing
  `syncFilterNames`/`adoptFilterNamesFromDriver` tools take only `role`, not a component `id`,
  suggesting the server already assumes at most one relevant component per role for this
  operation (consistent with `ensureConnected`'s own caveat about not distinguishing "exactly one
  connected" from "more than one") — `FilterWheel`'s wrapper can lean on the same assumption,
  but should throw a clear error rather than silently picking the first match if a rig ever
  declares two.

## Open questions

### Part 1: Translation layer — all now resolved upstream

All four of this section's original open questions are resolved as of INDIMCP-113's completion
(`docs/ToolSurfaceRedesign.md`'s "Decisions"/"Open decisions" sections in the INDIMCP-server repo):

1. **Action discriminator type — resolved: typed enum.** Every `action`/`kind`/`component`/`scope`
   parameter across every consolidated tool is a `Literal[...]` (Python) — a closed enum, not a
   free-form string. Confirmed directly against `server.py` while writing the tables above.
2. **Resources vs. tools for pure reads — resolved: stay tools, for now.** Decided against moving
   `list_config`/`configuration`(get)/`list_indi_drivers`/`frames`(list) to MCP resources, pending
   observing whether the actual production LLM client autonomously fetches resources (the
   INDIMCPKit-specific cost of either choice was already noted as "close to free" either way — see
   `docs/ToolSurfaceRedesign.md`'s open decision #1). No fourth `INDIMCPClient` primitive needed
   for now; revisit only if that upstream decision flips.
3. **`get_events` vs. `list_indi_messages` — resolved: dropped, not folded.** See "Server-side
   status" above and the dedicated `list_indi_messages` migration note — this is settled, but
   still real work for INDIMCPKit (`Camera.isCoolerOn()`), not a no-op.
4. **Exact wire shape per consolidated tool — resolved by reading the actual code.** The tables
   above are transcribed from `server.py`'s real signatures (confirmed on
   `feature/INDIMCP-119-plate-solving`, which merges everything through INDIMCP-120 plus its own
   INDIMCP-119 work), not inferred from `docs/ToolSurfaceRedesign.md`'s prose alone — still worth
   a real integration-test run per group before merging each INDIMCPKit PR, as ordinary
   verification, not because the shape is still speculative.

### Part 2: Camera & FilterWheel API

5. **`CCD_FRAME`'s actual element names** aren't confirmed anywhere in INDIMCP-server's source
   (only `CCD_MAX_X`/`CCD_MAX_Y` from `CCD_INFO` are) — verify against a real driver's property
   dump (e.g. via `get_device_properties` against the RPi test rig) before implementing `frame()`.
6. **`objectName` for a plain single-frame capture.** The user-visible request includes "object
   name" as a capture-time property, but INDIMCP-server's standalone `capture_frame` tool (and its
   backing `scripts/capture_frame.yaml`) has no `objectName` parameter at all — only
   `capture_light_sequence` does. If object-name-on-a-single-frame is wanted, that's a
   server-side addition (new parameter on the `capture_frame` tool/script) before INDIMCPKit has
   anything to wrap — flag to whoever owns INDIMCP-server's script catalog, it's out of this
   ticket's reach alone.
7. **Cooler power / capture format support is driver-dependent** — `coolerPowerPercent()` and any
   future capture-format API should tolerate a `nil`/absent property gracefully (already reflected
   in the proposed signatures above), not treat it as an error.
8. **Flat-sweep parity** — if `Camera` should also get a `runFlatCalibrationSweep` wrapper
   mirroring the sensor one above, that's IMCPKIT-33's territory (`INDIFlatCalibrationSweep.swift`
   already exists at the `INDIMCPClient` level, same gap) — raise it there rather than folding it
   in silently.
9. **`Component`/`Rig` copy-with helper** — needed for `setFilterName`'s implementation (see
   above); worth deciding whether it's a small hand-written `withSlots(_:)` on `Component` alone,
   or a more general copy-with mechanism other future single-field rig edits could reuse.
10. **`syncFilterNames`/`adoptFilterNamesFromDriver`'s `rigID` parameter naming** — that file's
    client methods take `rigID` (capital ID), inconsistent with `rigId` everywhere else in this
    kit. Not this ticket's job to fix (a public API rename), but worth a note for whoever eventually
    does a naming-consistency pass.

### Sequencing between Part 1 and Part 2

Both parts touch `Devices/Camera.swift`; Part 2 also touches `DeviceControl/INDICameraControl.swift`
and `Rigs/INDIRigReconciliation.swift`, which Part 1 also retargets. Land Part 1's device-actions
and configuration-entity groups (rollout steps 2–3 above) before starting Part 2's implementation,
rather than developing both against the same files in parallel.

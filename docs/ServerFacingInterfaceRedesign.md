# Server-Facing Interface Redesign (IMCPKIT-52)

## Why

INDIMCP-server currently registers 68 individual MCP tools. That's past the point where an LLM
client can reliably pick the right one from name/description/schema alone, so INDIMCP-113 is
consolidating them into ~26 tools, each parameterized by a `kind`/`action`/`component`
discriminator. The authoritative mapping (old tool → new tool/action) lives in the sibling
INDIMCP-server repo at `docs/ToolSurfaceRedesign.md`; this document doesn't repeat that mapping,
it defines how INDIMCPKit's *translation layer* absorbs it.

INDIMCP-113 already states the constraint this doc works within: **INDIMCPKit's public
`Mount`/`Camera`/`FilterWheel`/`Focuser`/`INDIRigs`/etc. API keeps its current EKOS-like shape.**
`Mount.park()` keeps its signature and behavior. Only the internal code that turns that call into
an MCP `tools/call` request changes — e.g. from calling a dedicated `park` tool to calling
`mount_action(rig_id, action: "park")`.

## Current shape of the translation layer

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

Note that INDIMCPKit doesn't yet wrap plate-solving or `abort_exposure` — nothing to migrate
there, but the new `camera_action`/`plate_solve` tools are worth picking up as new capability
once this refactor lands (separate ticket, out of scope here).

## What changes: per-group mapping

Using INDIMCP-113's tool inventory, restricted to tools INDIMCPKit actually calls today:

### Direct device actions (highest-traffic, safety-sensitive)

| File | Old tool(s) | New call |
|---|---|---|
| `INDIDeviceConnection.swift` | `connect`, `disconnect` | `set_connection(rig_id, role, connected: Bool)` |
| `INDIMountControl.swift` | `park`, `unpark`, `slew`, `track_off`, `set_track_mode`, `set_custom_tracking_rate` | `mount_action(rig_id, action, ...)` |
| `INDICameraControl.swift` | `cool_camera`, `cooler_on`, `cooler_off`, `capture_frame` | `camera_action(rig_id, action, ...)` |
| `INDIFilterWheelControl.swift` | `select_filter` | `filter_wheel_action(rig_id, action: "select", filterName)` |
| `INDIFocuserControl.swift` | `set_focus_position` | `focuser_action(rig_id, action: "set_position", position)` |

### Configuration entities (rig / observatory / script CRUD)

| File | Old tool(s) | New call |
|---|---|---|
| `INDIRigs.swift` | `list_rigs`, `get_rig`, `save_rig` | `list_config(kind: "rig")`, `get_config(kind: "rig", id)`, `save_config(kind: "rig", config, overwrite)` |
| `INDIRigReconciliation.swift` | `sync_filter_names`, `adopt_filter_names_from_driver` | both merge into `sync_filter_names(rig_id, role, direction: "to_driver"\|"from_driver")`; `check_rig`/`suggest_rig` unchanged |
| `INDIObservatories.swift` | `get_observatory`, `save_observatory` | `get_config(kind: "observatory", id)`, `save_config(kind: "observatory", ...)` |
| `INDIScripts.swift` | `list_scripts`, `get_script`, `save_script` | `list_config(kind: "script")`, `get_config(kind: "script", id)`, `save_config(kind: "script", ...)` |

(`draft_rig`/`draft_observatory` would map to `draft_config(kind:)` whenever INDIMCPKit wraps them.)

### Script run control

| File | Old tool(s) | New call |
|---|---|---|
| `INDIScriptRuns.swift` | `get_script_status`, `cancel_script`, `pause_script`, `resume_script` | `manage_script_run(run_id, action: "status"\|"cancel"\|"pause"\|"resume")` — `run_script` itself is unchanged |

### Calibration sweeps

| File | Old tool(s) | New call |
|---|---|---|
| `INDISensorCalibrationSweep.swift` | `run_sensor_calibration_sweep`, `get_sensor_calibration_sweep_status`, `cancel_sensor_calibration_sweep` | `run_calibration_sweep(kind: "sensor", rig_id, ...)`, `manage_calibration_sweep(sweep_id, action: "status"\|"cancel")` |
| `INDIFlatCalibrationSweep.swift` | `run_flat_calibration_sweep`, `get_flat_calibration_sweep_status`, `cancel_flat_calibration_sweep` | same tools, `kind: "flat"` |

### Frames

| File | Old tool(s) | New call |
|---|---|---|
| `INDIFrames.swift` | `list_frames`, `get_frame_metadata` | `frames(action: "list"\|"get", ...)` |
| `INDIFrames.swift` | `confirm_frame_transfer`, `delete_frame`, `purge_transferred_frames` | `manage_frame(action: "confirm_transfer"\|"delete"\|"purge", ...)` |

### INDI infrastructure

| File | Old tool(s) | New call |
|---|---|---|
| `ServerManagement/INDIServerManagement.swift` | `start_indi_server`, `stop_indi_server`, `restart_indi_server` | `manage_indi_infra(component: "server", action: "start"\|"stop"\|"restart", port?)` |
| `ServerManagement/INDIServerManagement.swift` | `get_indi_server_status` | `get_indi_status(component: "server")` |
| `DriverManagement/INDIDriverManagement.swift` | `start_indi_driver`, `stop_indi_driver` | `manage_indi_infra(component: "driver", action: "start"\|"stop", label)` |
| `DriverManagement/INDIDriverManagement.swift` | `list_indi_driver_catalog`, `list_running_indi_drivers` | `list_indi_drivers(scope: "catalog"\|"running")` |
| `Messaging/INDIMessaging.swift` | `start_indi_messaging`, `stop_indi_messaging` | `manage_indi_infra(component: "messaging", action: "start"\|"stop", host?, port?)` |
| `Messaging/INDIMessaging.swift` | `get_indi_messaging_status` | `get_indi_status(component: "messaging")` |
| `Messaging/INDIMessaging.swift` | `get_device_properties`, `send_indi_property` | `indi_property(action: "get"\|"set", device, name?, elements?)` |
| `Messaging/INDIMessaging.swift` | `list_indi_messages` | pending — see Open Questions; INDIMCP-113 hasn't finalized whether this folds into `get_events` |

`get_server_info` is unchanged and needs no translation-layer change.

## Design of the translation layer

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

This is a mechanical, per-group change: each of the seven tables above becomes one such helper
plus updated bodies in its file, with no change to any file outside `Sources/INDIMCPKit/*` (no
`Devices/Mount.swift` etc. changes — those already only call the `INDIMCPClient` extension
methods by name, never the tool string directly).

## Rollout plan

INDIMCPKit can't call a tool the server doesn't have yet — the two repos need to move in step,
group by group, not as one big-bang PR pair. Suggested order, roughly risk/traffic-ascending
except infra first since it's easiest to validate against the test app's Server tab:

1. **INDI infrastructure** — `manage_indi_infra`, `get_indi_status`, `list_indi_drivers`,
   `indi_property`. Low blast radius, already exercised by `INDIMCPKitTestApp`'s Server tab.
2. **Direct device actions** — `mount_action`/`camera_action`/`filter_wheel_action`/
   `focuser_action`/`set_connection`. Highest traffic and touches real hardware; do this once the
   pattern from (1) is validated.
3. **Configuration CRUD** — `list_config`/`get_config`/`save_config`/`draft_config`,
   `sync_filter_names`.
4. **Script run control** — `manage_script_run`.
5. **Calibration sweeps** — `run_calibration_sweep`/`manage_calibration_sweep`.
6. **Frames** — `frames`/`manage_frame`.
7. **Events / `list_indi_messages`** — once INDIMCP-113 resolves whether this folds into
   `get_events`.

Each PR should land only after its corresponding server-side group has actually shipped on
INDIMCP-113's branch (`feature/INDIMCP-113-tool-surface-redesign`) — otherwise the integration
tests (see below) have nothing to call.

## Testing

INDIMCPKit's `*IntegrationTests` (e.g. `INDIDeviceControlIntegrationTests`,
`INDIScriptRunsIntegrationTests`) run against a live INDIMCP-server instance
(`IndiServerTestLock.swift` serializes access to it), not a mock transport. That means:

- No public-API test changes are expected — the tests call `Mount.park()` etc., not tool names
  directly, so behavior/assertions stay the same.
- Each group's tests will fail until that group's server-side tools actually exist, which is the
  reason for pairing rollout to INDIMCP-113's own group-by-group progress rather than merging
  ahead of it.
- Once a server-side group lands, run that group's integration tests against it before merging
  the corresponding INDIMCPKit PR, and smoke-test the affected `INDIMCPKitTestApp` screen by hand
  (per this project's usual UI-verification practice) since the tests don't cover the SwiftUI
  layer.

## Open questions (tracked against INDIMCP-113)

1. **Action discriminator type** — INDIMCP-113 hasn't decided free-form `str` vs. typed enum for
   each tool's `action`/`kind` parameter. Doesn't block INDIMCPKit's own implementation (Swift
   sends a string either way), but a server-side enum gives us JSON-Schema-level validation for
   free.
2. **Resources vs. tools for pure reads** — if `list_config`/`get_config`/`list_indi_drivers`/
   `frames` (list mode) move to MCP resources instead of tools, INDIMCPKit's `callTool` primitive
   isn't the right one to reuse — a resource read is a different MCP operation. Watch for this;
   it would add a fourth primitive alongside `callTool`/`callToolList`/`callToolUnion` rather than
   just retargeting existing ones.
3. **`get_events` vs. `list_indi_messages`** — unresolved upstream; `INDIMessaging.swift`'s
   `listINDIMessages` mapping depends on it.
4. **Exact wire shape per consolidated tool** — the signature tables above describe the intended
   Python signature, not the confirmed JSON `structuredContent` shape. Validate each group's
   actual response shape against the real server as it lands (same way `callToolUnion`'s
   `{"result": ...}` wrapping was confirmed by testing against the real server, per
   `INDIMCPClient.swift`'s doc comments) rather than assuming it from the table.

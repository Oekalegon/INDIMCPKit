# Getting Started

Connect to an INDIMCP-server instance and issue your first commands.

## Overview

Every INDIMCPKit call goes through an ``INDIMCPClient``, which wraps the MCP session (transport
and protocol handshake) for a single INDIMCP-server instance. Create one, ``INDIMCPClient/connect()``
it, and it's ready for both direct client calls (server management, rigs, scripts, frames) and the
rig-scoped device handles built on top of it.

```swift
import INDIMCPKit

let client = INDIMCPClient(endpoint: URL(string: "http://telescope.local:8000/mcp")!)
try await client.connect()
```

INDIMCPKit only talks Streamable HTTP, matching INDIMCP-server's network-reachable deployment
mode — it deliberately does not support the server's `stdio` transport, which is local-testing-only.

### Talking to a device

Devices aren't addressed directly by name; they're reached through a **rig** — a saved,
named set of components (mount, camera, filter wheel, focuser, ...) each declaring which INDI
device fills which ``Role``. Get a rig-scoped handle from the client and call through it:

```swift
let mount = client.mount(rigId: "my-rig")
try await mount.park()

let camera = client.camera(rigId: "my-rig")
try await camera.coolCamera(targetTempC: -10)
```

See <doc:RigsAndObservatories> for how rigs are created and kept in sync with live hardware, and
<doc:DeviceControl> for the full set of device operations.

### Long-running operations

Anything that drives real hardware — parking, slewing, cooling, capturing — runs as a script on
the server and returns immediately with a ``ScriptRunStarted``, not a completed result. Poll for
its outcome, or use the convenience wait helpers:

```swift
let started = try await mount.park()
let status = try await client.waitForTerminalStatus(runId: started.runId)
```

See <doc:Scripts> for the full run lifecycle (progress, cancellation, pause/resume).

### Staying in sync

For UI that needs to reflect device state as it changes, ``ObservableDevice`` keeps a rig-scoped
device's properties live in memory, refreshed periodically and corrected by the live event stream
in between. See <doc:EventStreams> for the underlying `indi://messages`/`indi://scripts`
subscriptions it's built on.

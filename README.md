# INDIMCPKit

A Swift client API kit for talking to an [INDIMCP-server](https://github.com/Oekalegon/indi-mcp) instance, plus a
macOS test application that exercises it.

## What this is

[INDIMCP-server](../INDIMCP-server) exposes an INDI observatory (mount, camera, filter wheel, focuser, etc.) as a
set of [MCP](https://modelcontextprotocol.io) tools — server management, rig/observatory configuration, script
execution, and device control (park/unpark, slew, tracking, cooling, filter selection, focusing, exposure capture,
plate solving, frame management, ...).

INDIMCPKit is a Swift package that wraps that MCP tool surface in a typed, native Swift API so macOS/iOS apps can
drive an INDIMCP-server without talking MCP JSON-RPC directly.

### Scope: standard tools only

INDIMCPKit models the **standard, built-in tools** that ship with INDIMCP-server (the ones defined in `server.py`
itself). It deliberately does **not** attempt to statically model arbitrary user-authored scripts that a given
server instance may have saved — those are site-specific and outside a stable, versioned API surface.

It does still support user scripts generically: a server exposes `save_script`, `list_scripts`, `get_script` and
`run_script` as standard tools in their own right, so INDIMCPKit can list, save, and trigger a user's custom scripts
on the server through those generic calls. What it won't do is generate a typed Swift wrapper per custom script —
callers work with the script's declared parameter/result schema at runtime instead.

### Version alignment

Because the kit's tool definitions mirror a specific INDIMCP-server release, the package tracks which server
version it is aligned to (currently server `0.1.0`) and exposes that to consumers, so an app can detect drift
between the kit it was built against and the server it's talking to.

## Package layout

- **INDIMCPKit** (library) — MCP client core (connection/transport, tool discovery, typed request/response models)
  plus device-type abstractions built on top of the standard tools, e.g.:
  - **Mount** — connect/disconnect, park/unpark, slew to coordinates, tracking on/off, track mode/rate
  - **Camera** — connect/disconnect, cooler on/off, temperature, cool to target, capture a single exposure
    (gain/offset/ROI)
  - **FilterWheel** — select filter
  - **Focuser** — set focus position
  - **Event streams** — `messageEvents`/`scriptEvents` subscribe to the server's live
    `indi://messages`/`indi://scripts` resources (an `AsyncThrowingStream` per stream, scoped to a
    device/run if wanted); `getEvents` queries the durable event log to catch up on what a
    disconnected client missed, since the live streams are best-effort/live-only.
  - **Frames** — `listFrames`/`getFrameMetadata`/`confirmFrameTransfer`/`deleteFrame`/
    `purgeTransferredFrames` manage captured-frame metadata; `downloadFrame` streams a frame's raw
    bytes straight to a local file via the server's `GET /frames/{frameId}` route, never buffering
    the whole file in memory.
- **INDIMCPKit test app** (macOS, SwiftUI) — one screen per device type showing its default tool connections in
  action (e.g. Mount: park/unpark/track/slew; Camera: cooling + single exposure).

## Development workflow

This repository follows the same [Git Flow](https://nvie.com/posts/a-successful-git-branching-model/) setup as the
INDIMCP-server and ToDos projects:

- `develop` is the default branch and integration branch for ongoing work.
- `main` is reserved for releases and hotfixes only — never branched from or pushed to directly.
- Feature branches are cut from `develop`: `feature/IMCPKIT-<id>-<short-description>`.
- Hotfixes are cut from `main`: `hotfix/IMCPKIT-<id>-<short-description>`, merged back into both `main` and
  `develop`.
- Releases are cut from `develop`: `release/<version>`, merged into `main` (and back into `develop`).

Enforced via `.github/workflows/enforce-merge-policy.yml` (PRs into `main` only accepted from `release/*` or
`hotfix/*`; PRs into `develop` accepted from anything except `main`). CI build/test runs via
`.github/workflows/swift.yml` on every push/PR to `main` and `develop`.

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## Status

The standard/built-in MCP tool set is modeled (server/driver management, messaging, rigs,
observatories, scripts, and device control), the `Mount`/`Camera`/`FilterWheel`/`Focuser`
device-type abstractions are built on top of it, and the SwiftUI test app exercises them —
see the `INDIMCPKit` project in the todo tracker for what's still open (plate-solving/
astrometry-index tools, ongoing hardening).

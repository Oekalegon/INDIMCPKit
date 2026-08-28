# Rigs and Observatories

Model a physical hardware setup as a saved rig, and keep it in sync with what's actually connected.

## Overview

A ``Rig`` is a named set of ``Component``s, each declaring which ``Role`` it plays (mount, camera,
guide camera, filter wheel, focuser, rotator, power hub, observatory control, flat screen, dew
heater, or guide telescope). Device handles like ``Mount`` and ``Camera`` are always reached
through a rig — `client.mount(rigId:)`, not by device name directly.

```swift
let rigs = try await client.listRigs()
let rig = try await client.getRig(id: "my-rig")
try await client.saveRig(rig, overwrite: true)
```

``INDIMCPClient/saveRig(_:overwrite:)`` writes a rig definition to `rigs/<rig.id>.yaml` on the
server and reloads it — refuses to replace an existing file unless `overwrite` is set, since
reusing an `id` could otherwise silently destroy a previously saved rig.

### Reconciling a rig with live hardware

Because a rig is a saved configuration and INDI devices connect and disconnect independently,
INDIMCPKit provides reconciliation helpers rather than assuming the two never drift:

- ``INDIMCPClient/suggestRig()`` proposes which configured rig is likely mounted, by matching
  currently connected INDI devices — never auto-selects, just ranks candidates.
- ``INDIMCPClient/checkRig(id:)`` reports which of a rig's declared devices aren't currently
  connected, as a warning rather than a hard failure.
- ``INDIMCPClient/draftRig()`` pre-fills a ``RigDraft`` skeleton from whatever's currently
  connected, as a starting point for saving a new rig.
- ``INDIMCPClient/syncFilterNames(rigID:role:)`` and
  ``INDIMCPClient/adoptFilterNamesFromDriver(rigID:role:)`` push or pull filter-wheel slot names
  between a rig's saved configuration and the live driver — both deliberate, one-directional
  actions only, never run automatically.

All of these require INDI messaging to be running (`INDIMCPClient.startINDIMessaging()`).

## Observatories

An ``Observatory`` is a saved location (latitude/longitude/elevation) that can be attached to a
script run via `runScript(locationId:)` — currently consumed by `capture_frame`'s celestial-context
FITS headers.

```swift
let locations = try await client.listObservatories()
let location = try await client.getObservatory(id: "home-observatory")
try await client.saveObservatory(location, overwrite: true)
```

``INDIMCPClient/listObservatories()`` and ``INDIMCPClient/getObservatory(id:)`` list and fetch
saved locations, the same list/get shape as rigs and scripts.
``INDIMCPClient/saveObservatory(_:overwrite:)`` writes one to
`observatories/<observatory.id>.yaml` on the server — same overwrite-guard as `saveRig`.
``INDIMCPClient/draftObservatory()`` pre-fills an ``ObservatoryDraft`` from a
connected GPS/location-capable INDI device, the same "draft, never auto-save" pattern as
``INDIMCPClient/draftRig()``.

Optionally, an observatory can also declare real horizon obstructions — trees, buildings,
terrain — beyond the geometric horizon, via ``Observatory/horizonProfile``:

```swift
let location = Observatory(
    id: "home-observatory", name: "Home", latitudeDeg: 52.1, longitudeDeg: 5.1,
    horizonProfile: [
        HorizonPoint(azimuthDeg: 0, altitudeDeg: 5.2),
        HorizonPoint(azimuthDeg: 90, altitudeDeg: 12.9),
    ]
)
```

`nil` (the default) means no obstruction data is available, distinct from an explicit flat
horizon — see ``HorizonPoint`` for the point format.

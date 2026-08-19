# Server and Driver Management

Start, stop, and inspect the `indiserver` process and the INDI drivers running under it.

## Overview

Before any device can be controlled, `indiserver` itself has to be running on the server's device,
with the right INDI driver started for each piece of hardware. These are the lowest-level
management calls in INDIMCPKit — most consumers only need them once at startup, or when
recovering from a driver crash.

### The server process

```swift
try await client.startINDIServer()
let status = try await client.getINDIServerStatus()
```

``INDIMCPClient/startINDIServer(port:)`` restarts `indiserver` first if it's already running, so
it's safe to call unconditionally at app startup. ``INDIMCPClient/stopINDIServer()`` and
``INDIMCPClient/restartINDIServer(port:)`` round out the lifecycle;
``INDIMCPClient/getINDIServerStatus()`` reports whether it's running and on which port, decoded
into ``IndiServerStatus``.

### Drivers

```swift
let catalog = try await client.listINDIDriverCatalog()
try await client.startINDIDriver(label: "CCD Simulator")
let running = try await client.listRunningINDIDrivers()
```

``INDIMCPClient/listINDIDriverCatalog()`` lists every driver installed on the server's device,
whether or not it's currently running (``DriverInfo``). ``INDIMCPClient/startINDIDriver(label:)``
and ``INDIMCPClient/stopINDIDriver(label:)`` control a driver by its catalog label, and
``INDIMCPClient/listRunningINDIDrivers()`` reports which ones are active right now
(``DriverStatus``).

Once a driver is running and connected, it still needs to be mapped to a role in a saved rig
before device handles like ``Mount`` or ``Camera`` can reach it — see <doc:RigsAndObservatories>.

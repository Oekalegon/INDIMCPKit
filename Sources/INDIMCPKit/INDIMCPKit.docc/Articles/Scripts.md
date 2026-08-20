# Scripts

Run server-side scripts and observe their lifecycle from start to completion.

## Overview

Every device command in INDIMCPKit — parking, slewing, cooling, capturing — runs as a script on
the server. ``INDIMCPClient/runScript(scriptId:rigId:parameters:locationId:)`` starts one and
returns immediately with a ``ScriptRunStarted``; it never blocks until the script finishes, since
scripts drive physical hardware over sequences that can take minutes and are meant to keep running
even if the caller disconnects.

```swift
let started = try await client.runScript(scriptId: "park_mount", rigId: "my-rig")
```

## Following a run

Poll ``INDIMCPClient/getScriptStatus(runId:)`` for the current ``ScriptRunStatus`` — a
discriminated union covering both progress and every terminal outcome: ``ScriptRunStarted``,
``ScriptRunProgress``, ``ScriptRunCompleted``, ``ScriptRunFailed``, ``ScriptRunCancelled``,
``ScriptRunPaused``, ``ScriptRunResumed``, ``ScriptRunPauseRejected``, and ``ScriptRunError``.

For the common "start, then wait for the end" shape, use
``INDIMCPClient/waitForTerminalStatus(runId:pollInterval:maxAttempts:)`` instead of polling by
hand:

```swift
let status = try await client.waitForTerminalStatus(runId: started.runId)
```

Callers that need to observe intermediate progress (e.g. a capture sequence's frame-by-frame
updates) should poll `getScriptStatus` themselves rather than using the wait helper.

## Controlling a run

- ``INDIMCPClient/cancelScript(runId:)`` cancels a run, waiting for it to actually stop — this can
  block for as long as the run's current step takes, since INDIMCP-server only checks for
  cancellation between steps.
- ``INDIMCPClient/pauseScript(runId:)`` pauses a run at its next safe point, only if its script
  declared itself pausable — returns a ``PauseOutcome``.
- ``INDIMCPClient/resumeScript(runId:)`` resumes a previously paused run — returns a
  ``ResumeOutcome``.

## User-authored scripts

INDIMCPKit models the standard tool surface only, not any particular server instance's saved
scripts — those are site-specific. It still supports listing, saving, and running them generically
through ``Script`` and ``ScriptSummary``, working with each script's own declared ``Parameter``s
at runtime rather than a per-script typed Swift wrapper.

```swift
let scripts = try await client.listScripts()
let script = try await client.getScript(id: "my-script")
try await client.saveScript(script, overwrite: true)
```

``INDIMCPClient/listScripts()`` lists every loaded script, built-in and uploaded alike.
``INDIMCPClient/saveScript(_:overwrite:)`` uploads a script to `user_scripts/<script.id>.yaml` —
a separate directory from the built-ins, so an upload can never clobber or shadow one. The server
validates only declarative step data (no executable code), and rejects a script outright if it
doesn't fit the rest of the library — an unresolved `run_script` reference, a mismatched argument
type, a call cycle, or an `id` already used by a built-in script.

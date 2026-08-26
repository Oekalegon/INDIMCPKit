import MCP

/// Typed wrapper for the built-in `plate_solve_rig` script.
///
/// Like the composed capture sequences in `INDICaptureSequences.swift`, plate solving has no
/// dedicated server-side `@mcp.tool()` for the rig-based case — INDIMCP-119 dropped the old
/// standalone `plate_solve`/`plate_solve_until_precision` tools entirely rather than folding them
/// into the tool-surface redesign's consolidated tools, replacing both with `run_script`/
/// `manage_script_run` against a fixed built-in script id, `plate_solve_rig` (see
/// `docs/ServerFacingInterfaceRedesign.md`). Only `plate_solve_uploaded_frame` (for a
/// client-supplied FITS file, unrelated to any rig) and `manage_astrometry_index` remain dedicated
/// tools — out of scope here.
extension INDIMCPClient {
    /// Plate-solves the rig's camera and, by default, syncs the mount to the solved position.
    ///
    /// Omit `exposureSeconds` to solve whichever frame this run most recently captured, or set it
    /// to capture a fresh frame first. Omit `toleranceArcsec` for a single solve attempt (the old
    /// `plate_solve` tool's behavior); set it to retry instead (the old
    /// `plate_solve_until_precision` tool's behavior) — each attempt re-syncs and re-slews toward
    /// the mount's own commanded target (`TARGET_EOD_COORD`) until the solved position is within
    /// `toleranceArcsec` of it, or `maxAttempts` is exhausted. Run a slew first in that case, so
    /// `TARGET_EOD_COORD` is actually set to something meaningful — the script fails clearly at
    /// execution time otherwise, same as it does if `toleranceArcsec` is set without
    /// `exposureSeconds` or with `syncMount: false`.
    ///
    /// The solved position itself isn't returned by this call or by polling the run's status —
    /// `ScriptResult` (what a completed run produces) is generic across every script. It's written
    /// to the captured frame's WCS FITS headers instead; read those back via the frame-management
    /// tools once the run completes.
    ///
    /// Never blocks until the run finishes — poll `getScriptStatus(runId:)` for progress and the
    /// eventual completion/failure, or use `cancelScript`/`waitForTerminalStatus` — same as any
    /// other `runScript` call. `plate_solve_rig` itself isn't pausable.
    ///
    /// - Parameters:
    ///   - rigId: The rig to plate-solve against.
    ///   - exposureSeconds: Exposure length, in seconds, for a fresh capture (each retry attempt's
    ///     own capture, if `toleranceArcsec` is set). Omit to solve the most recently captured
    ///     frame instead — only valid when `toleranceArcsec` is also omitted.
    ///   - syncMount: Sync the mount's coordinates to the solved position once solved. Must stay
    ///     `true` if `toleranceArcsec` is set.
    ///   - toleranceArcsec: Retry until the solved position is within this many arcseconds of the
    ///     mount's commanded target, or `maxAttempts` is exhausted. Omit for a single solve
    ///     attempt with no retry. Requires `exposureSeconds` and `syncMount == true`.
    ///   - maxAttempts: Give up after this many solve attempts without reaching
    ///     `toleranceArcsec`. Only relevant when `toleranceArcsec` is set.
    ///   - timeoutSeconds: Maximum time to wait for `solve-field` to solve each attempt.
    ///   - binningX: Horizontal pixel binning for a fresh capture, if the camera supports it.
    ///     Ignored when `exposureSeconds` is omitted.
    ///   - binningY: Vertical pixel binning for a fresh capture, if the camera supports it.
    ///     Ignored when `exposureSeconds` is omitted.
    ///   - frameX: Sub-frame origin X, in unbinned pixels, for a fresh capture. Omit (with
    ///     `frameY`/`frameWidth`/`frameHeight`) for the full sensor. Ignored when
    ///     `exposureSeconds` is omitted.
    ///   - frameY: Sub-frame origin Y, in unbinned pixels, for a fresh capture.
    ///   - frameWidth: Sub-frame width, in unbinned pixels, for a fresh capture.
    ///   - frameHeight: Sub-frame height, in unbinned pixels, for a fresh capture.
    ///   - locationId: A saved `Observatory` this run's fresh capture (if any) should use, same
    ///     best-effort semantics as `runScript`'s `locationId`.
    /// - Returns: A `ScriptRunStarted` acknowledging the newly started run.
    /// - Throws: `INDIMCPClientError.toolCallFailed` if `rigId`/`locationId` doesn't resolve on
    ///   the server, or another `INDIMCPClientError` case on a transport/connection failure. A
    ///   `toleranceArcsec`/`exposureSeconds`/`syncMount` combination the script itself rejects
    ///   (see above) surfaces as a `.failed` status from a later `getScriptStatus`, not a thrown
    ///   error from this call.
    public func runPlateSolveRig(
        rigId: String,
        exposureSeconds: Double? = nil,
        syncMount: Bool = true,
        toleranceArcsec: Double? = nil,
        maxAttempts: Int = 3,
        timeoutSeconds: Double = 60,
        binningX: Int = 1,
        binningY: Int = 1,
        frameX: Int? = nil,
        frameY: Int? = nil,
        frameWidth: Int? = nil,
        frameHeight: Int? = nil,
        locationId: String? = nil
    ) async throws -> ScriptRunStarted {
        var parameters = mergingBinningAndFrameParameters(
            into: [
                "syncMount": .bool(syncMount),
                "maxAttempts": .int(maxAttempts),
                "timeoutSeconds": .double(timeoutSeconds),
            ],
            binningX: binningX, binningY: binningY,
            frameX: frameX, frameY: frameY, frameWidth: frameWidth, frameHeight: frameHeight
        )
        if let exposureSeconds {
            parameters["exposureSeconds"] = .double(exposureSeconds)
        }
        if let toleranceArcsec {
            parameters["toleranceArcsec"] = .double(toleranceArcsec)
        }
        return try await runScript(
            scriptId: "plate_solve_rig",
            rigId: rigId,
            parameters: parameters,
            locationId: locationId
        )
    }
}

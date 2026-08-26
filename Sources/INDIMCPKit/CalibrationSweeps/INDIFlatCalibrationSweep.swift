import MCP

extension INDIMCPClient {
    /// Runs `capture_flat_sequence` once per `(gain, offset, exposureSeconds)` combination,
    /// returning immediately with a `sweepId` — the flat-side counterpart to
    /// `runSensorCalibrationSweep`.
    ///
    /// `filterName`/`focusPosition`/`count` are shared across every combination in the sweep,
    /// matching what a single `capture_flat_sequence` invocation already takes. Combinations are
    /// the cartesian product of `gains`, `offsets`, and `exposureSecondsList` (in that nesting
    /// order); every argument list must be non-empty or the server rejects the call.
    ///
    /// Never blocks until the sweep finishes — a full sweep can run far longer than any single
    /// script (many combinations, each a real capture sequence) — poll
    /// `getFlatCalibrationSweepStatus(sweepId:)` for progress and the eventual terminal outcome,
    /// or `waitForTerminalFlatSweepStatus(sweepId:)` for the "start, then wait" shape, or use
    /// `cancelFlatCalibrationSweep` to stop it early.
    ///
    /// - Warning: Assumes the flat panel (or equivalent light source) is already staged in front
    ///   of the optics before calling this — INDIMCP-server has no way to prompt for or verify
    ///   that, and this call starts capturing immediately. The caller (typically a client app,
    ///   having confirmed with its human operator) is responsible for staging it first, the same
    ///   precondition a single `capture_flat_sequence` run already carries.
    /// - Parameters:
    ///   - rigId: The rig to run the sweep against.
    ///   - gains: Camera gain settings to sweep — outermost in the combination order, must be
    ///     non-empty.
    ///   - offsets: Camera offset settings to sweep — second in the combination order, must be
    ///     non-empty.
    ///   - exposureSecondsList: Flat exposure lengths (seconds) to sweep — innermost in the
    ///     combination order, must be non-empty.
    ///   - filterName: The filter to select before capturing, shared across every combination.
    ///   - focusPosition: The focuser position to move to before capturing, shared across every
    ///     combination.
    ///   - count: Flat frames captured per combination.
    ///   - binningX: Horizontal binning factor for every frame in the sweep.
    ///   - binningY: Vertical binning factor for every frame in the sweep.
    ///   - frameX: Sub-frame origin X, in unbinned pixels, shared by every frame in the sweep.
    ///     Omit (with `frameY`/`frameWidth`/`frameHeight`) for the full sensor.
    ///   - frameY: Sub-frame origin Y, in unbinned pixels.
    ///   - frameWidth: Sub-frame width, in unbinned pixels.
    ///   - frameHeight: Sub-frame height, in unbinned pixels.
    ///   - locationId: A saved `Observatory` this sweep's captures should use, if any — same
    ///     best-effort semantics as `runScript`'s `locationId`.
    /// - Returns: An acknowledgment carrying the new `sweepId` and total combination count.
    /// - Throws: `INDIMCPClientError.toolCallFailed` if `gains`, `offsets`, or
    ///   `exposureSecondsList` is empty, or if `rigId`/`locationId` doesn't resolve on the server.
    public func runFlatCalibrationSweep(
        rigId: String,
        gains: [Double],
        offsets: [Double],
        exposureSecondsList: [Double],
        filterName: String,
        focusPosition: Int,
        count: Int,
        binningX: Int = 1,
        binningY: Int = 1,
        frameX: Int? = nil,
        frameY: Int? = nil,
        frameWidth: Int? = nil,
        frameHeight: Int? = nil,
        locationId: String? = nil
    ) async throws -> FlatCalibrationSweepStarted {
        // Argument keys mirror INDIMCP-server's run_calibration_sweep parameter names exactly,
        // including its inconsistent snake_case/camelCase mix (rig_id/location_id vs.
        // gains/offsets/exposureSecondsList/filterName/focusPosition/count) — not a typo, don't
        // "fix" the casing to match this file's other calls or the server won't recognize the
        // argument. Same convention as runSensorCalibrationSweep.
        let extra = mergingBinningAndFrameParameters(
            into: [
                "gains": .array(gains.map { .double($0) }),
                "offsets": .array(offsets.map { .double($0) }),
                "exposureSecondsList": .array(exposureSecondsList.map { .double($0) }),
                "filterName": .string(filterName),
                "focusPosition": .int(focusPosition),
                "count": .int(count),
            ],
            binningX: binningX, binningY: binningY,
            frameX: frameX, frameY: frameY, frameWidth: frameWidth, frameHeight: frameHeight
        )
        return try await runCalibrationSweepTool(
            kind: "flat",
            rigId: rigId,
            extra: extra,
            locationId: locationId,
            decoding: FlatCalibrationSweepStarted.self
        )
    }

    /// Returns the most recently known status for a sweep started by `runFlatCalibrationSweep`.
    ///
    /// - Parameter sweepId: The sweep to query, as returned by `runFlatCalibrationSweep`.
    /// - Returns: The most recent `FlatCalibrationSweepStatus` recorded for `sweepId` —
    ///   `.started`/`.progress` if still running, or a terminal case once finished.
    /// - Throws: `INDIMCPClientError.toolCallFailed` if `sweepId` is unknown to the server (never
    ///   started, or evicted after enough other sweeps finished since).
    public func getFlatCalibrationSweepStatus(sweepId: String) async throws -> FlatCalibrationSweepStatus {
        try await manageCalibrationSweepTool(
            sweepId: sweepId,
            action: "status",
            decoding: FlatCalibrationSweepStatus.self
        )
    }

    /// Cancels a sweep started by `runFlatCalibrationSweep`, waiting for it to actually stop.
    ///
    /// Cancels whichever combination's capture run is currently in flight (if any) rather than
    /// letting it finish before stopping the sweep — same "can block for as long as the current
    /// step takes" caveat as `cancelScript`/`cancelSensorCalibrationSweep`, since that's exactly
    /// what this does under the hood for the in-flight combination.
    ///
    /// - Warning: Can block until the in-flight combination's current capture step finishes —
    ///   INDIMCP-server only checks for cancellation between steps, not preemptively mid-step.
    ///   Callers needing a bounded wait should race this against their own timeout.
    /// - Parameter sweepId: The sweep to cancel, as returned by `runFlatCalibrationSweep`.
    /// - Returns: The sweep's resulting terminal status — `.cancelled` if this call actually
    ///   stopped it, or whatever terminal status it had already reached on its own (finished or
    ///   failed) if cancellation lost that race.
    /// - Throws: `INDIMCPClientError.toolCallFailed` if `sweepId` is unknown to the server.
    public func cancelFlatCalibrationSweep(sweepId: String) async throws -> FlatCalibrationSweepStatus {
        try await manageCalibrationSweepTool(
            sweepId: sweepId,
            action: "cancel",
            decoding: FlatCalibrationSweepStatus.self
        )
    }

    /// Polls `getFlatCalibrationSweepStatus(sweepId:)` at `pollInterval` until it reaches a
    /// terminal status (`FlatCalibrationSweepStatus.isTerminal`), or throws
    /// `INDIMCPClientError.pollingTimedOut` after `maxAttempts` polls without one.
    ///
    /// Convenience for the common "start a sweep, then wait for it to finish" shape, mirroring
    /// `waitForTerminalSweepStatus(sweepId:)` for the bias/dark sweep — callers that need to
    /// observe intermediate progress (e.g. to show which combination is currently capturing)
    /// should poll `getFlatCalibrationSweepStatus` themselves instead.
    ///
    /// - Parameters:
    ///   - sweepId: The sweep to poll, as returned by `runFlatCalibrationSweep`.
    ///   - pollInterval: Delay between polls. Defaults to 500ms.
    ///   - maxAttempts: Maximum number of polls before giving up. Defaults to 120 (one minute at
    ///     the default `pollInterval`) — raise this for a sweep with many combinations, since each
    ///     one is a real capture sequence that can take far longer than a single script step.
    /// - Returns: The sweep's terminal `FlatCalibrationSweepStatus`.
    /// - Throws: `INDIMCPClientError.pollingTimedOut` if `maxAttempts` polls pass without the
    ///   sweep reaching a terminal status, or whatever `getFlatCalibrationSweepStatus` itself
    ///   throws (e.g. `toolCallFailed` for an unknown `sweepId`).
    public func waitForTerminalFlatSweepStatus(
        sweepId: String,
        pollInterval: Duration = .milliseconds(500),
        maxAttempts: Int = 120
    ) async throws -> FlatCalibrationSweepStatus {
        for _ in 0..<maxAttempts {
            let status = try await getFlatCalibrationSweepStatus(sweepId: sweepId)
            if status.isTerminal {
                return status
            }
            try await Task.sleep(for: pollInterval)
        }
        throw INDIMCPClientError.pollingTimedOut(runId: sweepId, attempts: maxAttempts)
    }
}

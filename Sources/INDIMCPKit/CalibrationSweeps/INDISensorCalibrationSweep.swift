import MCP

extension INDIMCPClient {
    /// Runs `capture_sensor_calibration_set` (bias + flat-dark) once per `(gain, offset,
    /// flatExposureSeconds)` combination, returning immediately with a `sweepId`.
    ///
    /// Needed because a script's own `parameters` can't carry list-valued inputs — INDIMCP-server
    /// has no way for a single `runScript` call to sweep a caller-supplied range of settings, so
    /// this is its own dedicated tool rather than a new script step. Combinations are the
    /// cartesian product of `gains`, `offsets`, and `flatExposureSecondsList` (in that nesting
    /// order); every argument list must be non-empty or the server rejects the call.
    /// `biasCount`/`darkCount`/`biasExposureSeconds` are shared across every combination in the
    /// sweep, matching what a single `capture_sensor_calibration_set` invocation already takes.
    ///
    /// Never blocks until the sweep finishes — a full sweep can run far longer than any single
    /// script (many combinations, each a real capture sequence) — poll
    /// `getSensorCalibrationSweepStatus(sweepId:)` for progress and the eventual terminal
    /// outcome, or `waitForTerminalSweepStatus(sweepId:)` for the "start, then wait" shape, or use
    /// `cancelSensorCalibrationSweep` to stop it early. Does not stage a flat panel or capture
    /// flats itself — this is the bias/flat-dark half of a calibration set only; the flat side is
    /// a separate sweep (IMCPKIT-33).
    public func runSensorCalibrationSweep(
        rigId: String,
        gains: [Double],
        offsets: [Double],
        flatExposureSecondsList: [Double],
        biasCount: Int,
        darkCount: Int,
        biasExposureSeconds: Double = 0,
        locationId: String? = nil
    ) async throws -> SensorCalibrationSweepStarted {
        var arguments: [String: Value] = [
            "rig_id": .string(rigId),
            "gains": .array(gains.map { .double($0) }),
            "offsets": .array(offsets.map { .double($0) }),
            "flatExposureSecondsList": .array(flatExposureSecondsList.map { .double($0) }),
            "biasCount": .int(biasCount),
            "darkCount": .int(darkCount),
            "biasExposureSeconds": .double(biasExposureSeconds),
        ]
        if let locationId {
            arguments["location_id"] = .string(locationId)
        }
        return try await callTool(
            "run_sensor_calibration_sweep",
            arguments: arguments,
            decoding: SensorCalibrationSweepStarted.self
        )
    }

    /// Returns the most recently known status for a sweep started by
    /// `runSensorCalibrationSweep`.
    public func getSensorCalibrationSweepStatus(sweepId: String) async throws -> SensorCalibrationSweepStatus {
        try await callToolUnion(
            "get_sensor_calibration_sweep_status",
            arguments: ["sweep_id": .string(sweepId)],
            decoding: SensorCalibrationSweepStatus.self
        )
    }

    /// Cancels a sweep started by `runSensorCalibrationSweep`, waiting for it to actually stop.
    ///
    /// Cancels whichever combination's capture run is currently in flight (if any) rather than
    /// letting it finish before stopping the sweep — same "can block for as long as the current
    /// step takes" caveat as `cancelScript`, since that's exactly what this does under the hood
    /// for the in-flight combination.
    public func cancelSensorCalibrationSweep(sweepId: String) async throws -> SensorCalibrationSweepStatus {
        try await callToolUnion(
            "cancel_sensor_calibration_sweep",
            arguments: ["sweep_id": .string(sweepId)],
            decoding: SensorCalibrationSweepStatus.self
        )
    }

    /// Polls `getSensorCalibrationSweepStatus(sweepId:)` at `pollInterval` until it reaches a
    /// terminal status (`SensorCalibrationSweepStatus.isTerminal`), or throws
    /// `INDIMCPClientError.pollingTimedOut` after `maxAttempts` polls without one.
    ///
    /// Convenience for the common "start a sweep, then wait for it to finish" shape, mirroring
    /// `waitForTerminalStatus(runId:)` for individual script runs — callers that need to observe
    /// intermediate progress (e.g. to show which combination is currently capturing) should poll
    /// `getSensorCalibrationSweepStatus` themselves instead.
    public func waitForTerminalSweepStatus(
        sweepId: String,
        pollInterval: Duration = .milliseconds(500),
        maxAttempts: Int = 120
    ) async throws -> SensorCalibrationSweepStatus {
        for _ in 0..<maxAttempts {
            let status = try await getSensorCalibrationSweepStatus(sweepId: sweepId)
            if status.isTerminal {
                return status
            }
            try await Task.sleep(for: pollInterval)
        }
        throw INDIMCPClientError.pollingTimedOut(runId: sweepId, attempts: maxAttempts)
    }
}

/// One `(gain, offset, flatExposureSeconds)` combination's finished capture run, as reported in
/// `SensorCalibrationSweepProgress`/`SensorCalibrationSweepCompleted`/`SensorCalibrationSweepFailed`/
/// `SensorCalibrationSweepCancelled`'s `results`.
///
/// Mirrors INDIMCP-server's `SensorCalibrationSweepCombinationResult`
/// (`sensor_calibration_sweep.py`).
///
/// `runId` always equals the sweep's own `sweepId` — every combination in a sweep is deliberately
/// started with the same `run_id` (see INDIMCP-server's module doc comment for why: it lets
/// `listFrames(runId:)` retrieve every frame the whole sweep captured in one call), kept as its
/// own field for shape symmetry with `ScriptRunStatus`, not because it varies per combination.
public struct SensorCalibrationSweepCombinationResult: Codable, Sendable, Hashable {
    public let gain: Double
    public let offset: Double
    public let flatExposureSeconds: Double
    public let runId: String
    public let status: ScriptRunStatus

    public init(
        gain: Double,
        offset: Double,
        flatExposureSeconds: Double,
        runId: String,
        status: ScriptRunStatus
    ) {
        self.gain = gain
        self.offset = offset
        self.flatExposureSeconds = flatExposureSeconds
        self.runId = runId
        self.status = status
    }
}

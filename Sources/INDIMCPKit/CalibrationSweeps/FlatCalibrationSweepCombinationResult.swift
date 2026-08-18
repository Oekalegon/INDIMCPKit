/// One `(gain, offset, exposureSeconds)` combination's finished capture run, as reported in
/// `FlatCalibrationSweepProgress`/`FlatCalibrationSweepCompleted`/`FlatCalibrationSweepFailed`/
/// `FlatCalibrationSweepCancelled`'s `results`.
///
/// Mirrors INDIMCP-server's `FlatCalibrationSweepCombinationResult` (`flat_calibration_sweep.py`)
/// — the flat-side counterpart to `SensorCalibrationSweepCombinationResult`.
///
/// `runId` always equals the sweep's own `sweepId` — every combination in a sweep is deliberately
/// started with the same `run_id` (see `SensorCalibrationSweepCombinationResult`'s doc comment for
/// why), kept as its own field for shape symmetry with `ScriptRunStatus`, not because it varies
/// per combination.
public struct FlatCalibrationSweepCombinationResult: Codable, Sendable, Hashable {
    /// This combination's camera gain setting.
    public let gain: Double
    /// This combination's camera offset setting.
    public let offset: Double
    /// This combination's flat exposure length, in seconds.
    public let exposureSeconds: Double
    /// Always equals the owning sweep's own `sweepId` — see this type's own doc comment for why.
    public let runId: String
    /// Whatever `waitForTerminalStatus`/`waitForCompletion` returned for this combination's
    /// capture run — `.completed`/`.failed`/`.cancelled` in practice, never a non-terminal case.
    public let status: ScriptRunStatus

    /// Creates one combination's finished capture-run result.
    ///
    /// - Parameters:
    ///   - gain: This combination's camera gain setting.
    ///   - offset: This combination's camera offset setting.
    ///   - exposureSeconds: This combination's flat exposure length, in seconds.
    ///   - runId: The owning sweep's `sweepId`.
    ///   - status: This combination's capture run's terminal status.
    public init(
        gain: Double,
        offset: Double,
        exposureSeconds: Double,
        runId: String,
        status: ScriptRunStatus
    ) {
        self.gain = gain
        self.offset = offset
        self.exposureSeconds = exposureSeconds
        self.runId = runId
        self.status = status
    }
}

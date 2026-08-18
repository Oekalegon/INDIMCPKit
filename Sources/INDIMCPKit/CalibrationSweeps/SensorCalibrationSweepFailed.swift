/// A sweep stopped because one combination's run didn't complete successfully.
///
/// Mirrors INDIMCP-server's `SensorCalibrationSweepFailed` (`sensor_calibration_sweep.py`),
/// `kind == "sensorCalibrationSweepFailed"`.
///
/// `failedAtCombination` is a 0-indexed position into the sweep's own combination order (the
/// cartesian product of `gains`, `offsets`, `flatExposureSecondsList` in that nesting order) —
/// the failing combination's own outcome is the last entry of `results`.
public struct SensorCalibrationSweepFailed: Codable, Sendable, Hashable {
    public let sweepId: String
    public let rigId: String
    public let failedAtCombination: Int
    public let message: String
    public let results: [SensorCalibrationSweepCombinationResult]

    public init(
        sweepId: String,
        rigId: String,
        failedAtCombination: Int,
        message: String,
        results: [SensorCalibrationSweepCombinationResult]
    ) {
        self.sweepId = sweepId
        self.rigId = rigId
        self.failedAtCombination = failedAtCombination
        self.message = message
        self.results = results
    }
}

/// A sweep that ran every combination to a successful completion.
///
/// Mirrors INDIMCP-server's `SensorCalibrationSweepCompleted` (`sensor_calibration_sweep.py`),
/// `kind == "sensorCalibrationSweepCompleted"`.
public struct SensorCalibrationSweepCompleted: Codable, Sendable, Hashable {
    public let sweepId: String
    public let rigId: String
    public let finishedAt: String
    public let results: [SensorCalibrationSweepCombinationResult]

    public init(
        sweepId: String,
        rigId: String,
        finishedAt: String,
        results: [SensorCalibrationSweepCombinationResult]
    ) {
        self.sweepId = sweepId
        self.rigId = rigId
        self.finishedAt = finishedAt
        self.results = results
    }
}

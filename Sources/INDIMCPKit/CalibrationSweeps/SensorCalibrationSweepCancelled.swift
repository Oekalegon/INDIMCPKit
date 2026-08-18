/// The terminal status of a sweep stopped via `cancelSensorCalibrationSweep`.
///
/// Mirrors INDIMCP-server's `SensorCalibrationSweepCancelled` (`sensor_calibration_sweep.py`),
/// `kind == "sensorCalibrationSweepCancelled"`.
public struct SensorCalibrationSweepCancelled: Codable, Sendable, Hashable {
    public let sweepId: String
    public let rigId: String
    public let cancelledAtCombination: Int
    public let finishedAt: String
    public let results: [SensorCalibrationSweepCombinationResult]

    public init(
        sweepId: String,
        rigId: String,
        cancelledAtCombination: Int,
        finishedAt: String,
        results: [SensorCalibrationSweepCombinationResult]
    ) {
        self.sweepId = sweepId
        self.rigId = rigId
        self.cancelledAtCombination = cancelledAtCombination
        self.finishedAt = finishedAt
        self.results = results
    }
}

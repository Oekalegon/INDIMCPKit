/// Acknowledges a sensor calibration sweep has started; returned immediately by
/// `runSensorCalibrationSweep`.
///
/// Mirrors INDIMCP-server's `SensorCalibrationSweepStarted` (`sensor_calibration_sweep.py`),
/// `kind == "sensorCalibrationSweepStarted"`.
public struct SensorCalibrationSweepStarted: Codable, Sendable, Hashable {
    public let sweepId: String
    public let rigId: String
    public let totalCombinations: Int
    public let startedAt: String

    public init(sweepId: String, rigId: String, totalCombinations: Int, startedAt: String) {
        self.sweepId = sweepId
        self.rigId = rigId
        self.totalCombinations = totalCombinations
        self.startedAt = startedAt
    }
}

/// Acknowledges a sensor calibration sweep has started; returned immediately by
/// `runSensorCalibrationSweep`.
///
/// Mirrors INDIMCP-server's `SensorCalibrationSweepStarted` (`sensor_calibration_sweep.py`),
/// `kind == "sensorCalibrationSweepStarted"`.
public struct SensorCalibrationSweepStarted: Codable, Sendable, Hashable {
    /// Identifies this sweep for `getSensorCalibrationSweepStatus`/`cancelSensorCalibrationSweep`.
    public let sweepId: String
    /// The rig the sweep is running against.
    public let rigId: String
    /// The total number of `(gain, offset, flatExposureSeconds)` combinations this sweep will run
    /// — the cartesian product of the lists passed to `runSensorCalibrationSweep`.
    public let totalCombinations: Int
    /// When the sweep started, as an ISO 8601 timestamp string.
    public let startedAt: String

    /// Creates a sweep-started acknowledgment.
    ///
    /// - Parameters:
    ///   - sweepId: Identifies this sweep for later status/cancel calls.
    ///   - rigId: The rig the sweep is running against.
    ///   - totalCombinations: The total number of combinations this sweep will run.
    ///   - startedAt: When the sweep started, as an ISO 8601 timestamp string.
    public init(sweepId: String, rigId: String, totalCombinations: Int, startedAt: String) {
        self.sweepId = sweepId
        self.rigId = rigId
        self.totalCombinations = totalCombinations
        self.startedAt = startedAt
    }
}

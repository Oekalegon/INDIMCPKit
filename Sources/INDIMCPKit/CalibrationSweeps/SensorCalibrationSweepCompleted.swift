/// A sweep that ran every combination to a successful completion.
///
/// Mirrors INDIMCP-server's `SensorCalibrationSweepCompleted` (`sensor_calibration_sweep.py`),
/// `kind == "sensorCalibrationSweepCompleted"`.
public struct SensorCalibrationSweepCompleted: Codable, Sendable, Hashable {
    /// The sweep that completed.
    public let sweepId: String
    /// The rig the sweep ran against.
    public let rigId: String
    /// When the sweep finished, as an ISO 8601 timestamp string.
    public let finishedAt: String
    /// Every combination's finished capture run, in the sweep's combination order.
    public let results: [SensorCalibrationSweepCombinationResult]

    /// Creates a sweep-completed terminal status.
    ///
    /// - Parameters:
    ///   - sweepId: The sweep that completed.
    ///   - rigId: The rig the sweep ran against.
    ///   - finishedAt: When the sweep finished, as an ISO 8601 timestamp string.
    ///   - results: Every combination's finished capture run.
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

/// The terminal status of a sweep stopped via `cancelSensorCalibrationSweep`.
///
/// Mirrors INDIMCP-server's `SensorCalibrationSweepCancelled` (`sensor_calibration_sweep.py`),
/// `kind == "sensorCalibrationSweepCancelled"`.
public struct SensorCalibrationSweepCancelled: Codable, Sendable, Hashable {
    /// The sweep that was cancelled.
    public let sweepId: String
    /// The id of the rig the sweep ran against.
    public let rigId: String
    /// 0-indexed position, in the sweep's own combination order, of the combination that was in
    /// flight (or about to start) when cancellation took effect.
    public let cancelledAtCombination: Int
    /// When cancellation actually finished stopping the sweep, as an ISO 8601 timestamp string.
    public let finishedAt: String
    /// Every combination finished before cancellation took effect, in the sweep's combination
    /// order.
    public let results: [SensorCalibrationSweepCombinationResult]

    /// Creates a sweep-cancelled terminal status.
    ///
    /// - Parameters:
    ///   - sweepId: The sweep that was cancelled.
    ///   - rigId: The id of the rig the sweep ran against.
    ///   - cancelledAtCombination: 0-indexed position of the combination in flight when
    ///     cancellation took effect.
    ///   - finishedAt: When cancellation finished, as an ISO 8601 timestamp string.
    ///   - results: Every combination finished before cancellation took effect.
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

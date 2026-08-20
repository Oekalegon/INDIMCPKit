/// Acknowledges a flat calibration sweep has started; returned immediately by
/// `runFlatCalibrationSweep`.
///
/// Mirrors INDIMCP-server's `FlatCalibrationSweepStarted` (`flat_calibration_sweep.py`),
/// `kind == "flatCalibrationSweepStarted"`.
public struct FlatCalibrationSweepStarted: Codable, Sendable, Hashable {
    /// Identifies this sweep for `getFlatCalibrationSweepStatus`/`cancelFlatCalibrationSweep`.
    public let sweepId: String
    /// The id of the rig the sweep is running against.
    public let rigId: String
    /// The total number of `(gain, offset, exposureSeconds)` combinations this sweep will run —
    /// the cartesian product of the lists passed to `runFlatCalibrationSweep`.
    public let totalCombinations: Int
    /// When the sweep started, as an ISO 8601 timestamp string.
    public let startedAt: String

    /// Creates a sweep-started acknowledgment.
    ///
    /// - Parameters:
    ///   - sweepId: Identifies this sweep for later status/cancel calls.
    ///   - rigId: The id of the rig the sweep is running against.
    ///   - totalCombinations: The total number of combinations this sweep will run.
    ///   - startedAt: When the sweep started, as an ISO 8601 timestamp string.
    public init(sweepId: String, rigId: String, totalCombinations: Int, startedAt: String) {
        self.sweepId = sweepId
        self.rigId = rigId
        self.totalCombinations = totalCombinations
        self.startedAt = startedAt
    }
}

/// The most recently reported progress for a sweep, fetched via `getSensorCalibrationSweepStatus`.
///
/// Mirrors INDIMCP-server's `SensorCalibrationSweepProgress` (`sensor_calibration_sweep.py`),
/// `kind == "sensorCalibrationSweepProgress"`.
///
/// `results` carries every combination finished so far, same shape as the terminal statuses' own
/// `results` — a caller can inspect each combination's outcome as it lands rather than waiting
/// for the whole sweep to reach a terminal state. `currentRunId` is `nil` between combinations
/// and the sweep's own `sweepId` while one is in flight (every combination shares that id — see
/// `SensorCalibrationSweepCombinationResult`'s doc comment) — kept mainly to say plainly whether
/// a combination is currently running at all.
public struct SensorCalibrationSweepProgress: Codable, Sendable, Hashable {
    public let sweepId: String
    public let rigId: String
    public let combinationsCompleted: Int
    public let totalCombinations: Int
    public let currentRunId: String?
    public let results: [SensorCalibrationSweepCombinationResult]

    public init(
        sweepId: String,
        rigId: String,
        combinationsCompleted: Int,
        totalCombinations: Int,
        currentRunId: String?,
        results: [SensorCalibrationSweepCombinationResult]
    ) {
        self.sweepId = sweepId
        self.rigId = rigId
        self.combinationsCompleted = combinationsCompleted
        self.totalCombinations = totalCombinations
        self.currentRunId = currentRunId
        self.results = results
    }
}

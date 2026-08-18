/// The most recently reported progress for a sweep, fetched via `getFlatCalibrationSweepStatus`.
///
/// Mirrors INDIMCP-server's `FlatCalibrationSweepProgress` (`flat_calibration_sweep.py`),
/// `kind == "flatCalibrationSweepProgress"`.
///
/// `results` carries every combination finished so far, same shape as the terminal statuses' own
/// `results` — a caller can inspect each combination's outcome as it lands rather than waiting
/// for the whole sweep to reach a terminal state. `currentRunId` is `nil` between combinations
/// and the sweep's own `sweepId` while one is in flight (every combination shares that id — see
/// `FlatCalibrationSweepCombinationResult`'s doc comment) — kept mainly to say plainly whether a
/// combination is currently running at all.
public struct FlatCalibrationSweepProgress: Codable, Sendable, Hashable {
    /// The sweep this progress report is for.
    public let sweepId: String
    /// The rig the sweep is running against.
    public let rigId: String
    /// How many combinations have finished (successfully or not) so far.
    public let combinationsCompleted: Int
    /// The total number of combinations this sweep will run.
    public let totalCombinations: Int
    /// `nil` between combinations; the sweep's own `sweepId` while one is currently capturing —
    /// see this type's own doc comment for why it doesn't vary per in-flight combination.
    public let currentRunId: String?
    /// Every combination finished so far, in the order they completed.
    public let results: [FlatCalibrationSweepCombinationResult]

    /// Creates a sweep progress report.
    ///
    /// - Parameters:
    ///   - sweepId: The sweep this progress report is for.
    ///   - rigId: The rig the sweep is running against.
    ///   - combinationsCompleted: How many combinations have finished so far.
    ///   - totalCombinations: The total number of combinations this sweep will run.
    ///   - currentRunId: `nil` between combinations; the sweep's own `sweepId` while one is
    ///     currently capturing.
    ///   - results: Every combination finished so far.
    public init(
        sweepId: String,
        rigId: String,
        combinationsCompleted: Int,
        totalCombinations: Int,
        currentRunId: String?,
        results: [FlatCalibrationSweepCombinationResult]
    ) {
        self.sweepId = sweepId
        self.rigId = rigId
        self.combinationsCompleted = combinationsCompleted
        self.totalCombinations = totalCombinations
        self.currentRunId = currentRunId
        self.results = results
    }
}

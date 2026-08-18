/// A sweep stopped because one combination's run didn't complete successfully.
///
/// Mirrors INDIMCP-server's `FlatCalibrationSweepFailed` (`flat_calibration_sweep.py`),
/// `kind == "flatCalibrationSweepFailed"`.
///
/// `failedAtCombination` is a 0-indexed position into the sweep's own combination order (the
/// cartesian product of `gains`, `offsets`, `exposureSecondsList` in that nesting order) — the
/// failing combination's own outcome is the last entry of `results`.
public struct FlatCalibrationSweepFailed: Codable, Sendable, Hashable {
    /// The sweep that failed.
    public let sweepId: String
    /// The rig the sweep ran against.
    public let rigId: String
    /// 0-indexed position of the failing combination in the sweep's own combination order.
    public let failedAtCombination: Int
    /// A human-readable description of why the failing combination's run didn't complete
    /// successfully.
    public let message: String
    /// Every combination finished before the failure, in the sweep's combination order — the
    /// failing combination's own outcome is the last entry.
    public let results: [FlatCalibrationSweepCombinationResult]

    /// Creates a sweep-failed terminal status.
    ///
    /// - Parameters:
    ///   - sweepId: The sweep that failed.
    ///   - rigId: The rig the sweep ran against.
    ///   - failedAtCombination: 0-indexed position of the failing combination.
    ///   - message: A human-readable description of the failure.
    ///   - results: Every combination finished before the failure.
    public init(
        sweepId: String,
        rigId: String,
        failedAtCombination: Int,
        message: String,
        results: [FlatCalibrationSweepCombinationResult]
    ) {
        self.sweepId = sweepId
        self.rigId = rigId
        self.failedAtCombination = failedAtCombination
        self.message = message
        self.results = results
    }
}

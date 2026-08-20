/// Whatever `getFlatCalibrationSweepStatus`/`cancelFlatCalibrationSweep` currently has on file
/// for a `sweepId` — one of these `kind`-tagged envelopes, whichever was most recently recorded.
///
/// Mirrors INDIMCP-server's `FlatCalibrationSweepStatus` (`flat_calibration_sweep.py`), a `Union`
/// of five TypedDicts discriminated by their own `kind` field — same shape and same reason for a
/// hand-written `Codable` conformance as `SensorCalibrationSweepStatus`.
public enum FlatCalibrationSweepStatus: Sendable, Hashable {
    /// The sweep has just started; no combination has finished yet.
    case started(FlatCalibrationSweepStarted)
    /// The sweep is in progress; some combinations may have finished already.
    case progress(FlatCalibrationSweepProgress)
    /// The sweep ran every combination to a successful completion.
    case completed(FlatCalibrationSweepCompleted)
    /// The sweep stopped because one combination's run didn't complete successfully.
    case failed(FlatCalibrationSweepFailed)
    /// The sweep was stopped early via `cancelFlatCalibrationSweep`.
    case cancelled(FlatCalibrationSweepCancelled)

    /// Whether this status is a final outcome for the sweep — no further
    /// `getFlatCalibrationSweepStatus` call will ever change it.
    public var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled:
            return true
        case .started, .progress:
            return false
        }
    }
}

extension FlatCalibrationSweepStatus: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
    }

    /// Decodes whichever `kind`-tagged case the payload's `kind` field names.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)
        switch kind {
        case "flatCalibrationSweepStarted":
            self = .started(try FlatCalibrationSweepStarted(from: decoder))
        case "flatCalibrationSweepProgress":
            self = .progress(try FlatCalibrationSweepProgress(from: decoder))
        case "flatCalibrationSweepCompleted":
            self = .completed(try FlatCalibrationSweepCompleted(from: decoder))
        case "flatCalibrationSweepFailed":
            self = .failed(try FlatCalibrationSweepFailed(from: decoder))
        case "flatCalibrationSweepCancelled":
            self = .cancelled(try FlatCalibrationSweepCancelled(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind,
                in: container,
                debugDescription: "Unknown flat calibration sweep status kind: \(kind)"
            )
        }
    }

    /// Encodes the wrapped case together with its discriminating `kind` field.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .started(let value):
            try container.encode("flatCalibrationSweepStarted", forKey: .kind)
            try value.encode(to: encoder)
        case .progress(let value):
            try container.encode("flatCalibrationSweepProgress", forKey: .kind)
            try value.encode(to: encoder)
        case .completed(let value):
            try container.encode("flatCalibrationSweepCompleted", forKey: .kind)
            try value.encode(to: encoder)
        case .failed(let value):
            try container.encode("flatCalibrationSweepFailed", forKey: .kind)
            try value.encode(to: encoder)
        case .cancelled(let value):
            try container.encode("flatCalibrationSweepCancelled", forKey: .kind)
            try value.encode(to: encoder)
        }
    }
}

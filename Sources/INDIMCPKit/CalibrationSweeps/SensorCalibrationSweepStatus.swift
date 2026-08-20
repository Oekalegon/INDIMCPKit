/// Whatever `getSensorCalibrationSweepStatus`/`cancelSensorCalibrationSweep` currently has on
/// file for a `sweepId` — one of these `kind`-tagged envelopes, whichever was most recently
/// recorded.
///
/// Mirrors INDIMCP-server's `SensorCalibrationSweepStatus` (`sensor_calibration_sweep.py`), a
/// `Union` of five TypedDicts discriminated by their own `kind` field — same shape and same
/// reason for a hand-written `Codable` conformance as `ScriptRunStatus`.
public enum SensorCalibrationSweepStatus: Sendable, Hashable {
    /// The sweep has just started; no combination has finished yet.
    case started(SensorCalibrationSweepStarted)
    /// The sweep is in progress; some combinations may have finished already.
    case progress(SensorCalibrationSweepProgress)
    /// The sweep ran every combination to a successful completion.
    case completed(SensorCalibrationSweepCompleted)
    /// The sweep stopped because one combination's run didn't complete successfully.
    case failed(SensorCalibrationSweepFailed)
    /// The sweep was stopped early via `cancelSensorCalibrationSweep`.
    case cancelled(SensorCalibrationSweepCancelled)

    /// Whether this status is a final outcome for the sweep — no further
    /// `getSensorCalibrationSweepStatus` call will ever change it.
    public var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled:
            return true
        case .started, .progress:
            return false
        }
    }
}

extension SensorCalibrationSweepStatus: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
    }

    /// Decodes whichever `kind`-tagged case the payload's `kind` field names.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)
        switch kind {
        case "sensorCalibrationSweepStarted":
            self = .started(try SensorCalibrationSweepStarted(from: decoder))
        case "sensorCalibrationSweepProgress":
            self = .progress(try SensorCalibrationSweepProgress(from: decoder))
        case "sensorCalibrationSweepCompleted":
            self = .completed(try SensorCalibrationSweepCompleted(from: decoder))
        case "sensorCalibrationSweepFailed":
            self = .failed(try SensorCalibrationSweepFailed(from: decoder))
        case "sensorCalibrationSweepCancelled":
            self = .cancelled(try SensorCalibrationSweepCancelled(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind,
                in: container,
                debugDescription: "Unknown sensor calibration sweep status kind: \(kind)"
            )
        }
    }

    /// Encodes the wrapped case together with its discriminating `kind` field.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .started(let value):
            try container.encode("sensorCalibrationSweepStarted", forKey: .kind)
            try value.encode(to: encoder)
        case .progress(let value):
            try container.encode("sensorCalibrationSweepProgress", forKey: .kind)
            try value.encode(to: encoder)
        case .completed(let value):
            try container.encode("sensorCalibrationSweepCompleted", forKey: .kind)
            try value.encode(to: encoder)
        case .failed(let value):
            try container.encode("sensorCalibrationSweepFailed", forKey: .kind)
            try value.encode(to: encoder)
        case .cancelled(let value):
            try container.encode("sensorCalibrationSweepCancelled", forKey: .kind)
            try value.encode(to: encoder)
        }
    }
}

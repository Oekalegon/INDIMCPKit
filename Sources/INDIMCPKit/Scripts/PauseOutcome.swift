/// The result of a `pauseScript` call.
///
/// Mirrors INDIMCP-server's `pause_script` return type, `ScriptRunPaused | ScriptRunPauseRejected`
/// (`server.py`) — decoded via the same `kind`-tag dispatch as `ScriptRunStatus`, just over a
/// smaller set of cases.
public enum PauseOutcome: Sendable, Hashable {
    case paused(ScriptRunPaused)
    case rejected(ScriptRunPauseRejected)
}

extension PauseOutcome: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)
        switch kind {
        case "scriptPaused":
            self = .paused(try ScriptRunPaused(from: decoder))
        case "scriptPauseRejected":
            self = .rejected(try ScriptRunPauseRejected(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind,
                in: container,
                debugDescription: "Unknown pause outcome kind: \(kind)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .paused(let value):
            try container.encode("scriptPaused", forKey: .kind)
            try value.encode(to: encoder)
        case .rejected(let value):
            try container.encode("scriptPauseRejected", forKey: .kind)
            try value.encode(to: encoder)
        }
    }
}

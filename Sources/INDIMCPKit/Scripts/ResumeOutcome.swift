/// The result of a `resumeScript` call.
///
/// Mirrors INDIMCP-server's `resume_script` return type,
/// `ScriptRunResumed | ScriptRunPauseRejected` (`server.py`) — decoded via the same `kind`-tag
/// dispatch as `ScriptRunStatus`, just over a smaller set of cases. `ScriptRunPauseRejected` is
/// reused here for a rejected resume too, per the server's own docstring: a run whose script
/// isn't pausable, or one already terminal, can't be paused *or* resumed.
public enum ResumeOutcome: Sendable, Hashable {
    /// The run was resumed.
    case resumed(ScriptRunResumed)
    /// The run couldn't be paused or resumed.
    case rejected(ScriptRunPauseRejected)
}

extension ResumeOutcome: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
    }

    /// Decodes a resume outcome, dispatching on its `kind` tag.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)
        switch kind {
        case "scriptResumed":
            self = .resumed(try ScriptRunResumed(from: decoder))
        case "scriptPauseRejected":
            self = .rejected(try ScriptRunPauseRejected(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind,
                in: container,
                debugDescription: "Unknown resume outcome kind: \(kind)"
            )
        }
    }

    /// Encodes this resume outcome, tagged with its `kind`.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .resumed(let value):
            try container.encode("scriptResumed", forKey: .kind)
            try value.encode(to: encoder)
        case .rejected(let value):
            try container.encode("scriptPauseRejected", forKey: .kind)
            try value.encode(to: encoder)
        }
    }
}

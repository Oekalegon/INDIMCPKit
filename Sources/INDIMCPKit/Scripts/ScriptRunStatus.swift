/// Whatever `getScriptStatus`/`cancelScript` currently has on file for a `runId` — one of these
/// `kind`-tagged envelopes, whichever was most recently recorded.
///
/// Mirrors INDIMCP-server's `ScriptRunStatus` (`script_runs.py`), a `Union` of eight TypedDicts
/// discriminated by their own `kind` field. FastMCP can't put a discriminated union directly in
/// `structuredContent` any more than it can a bare list (see `INDIMCPClient.callToolUnion`'s doc
/// comment) — decoding here picks the matching case from the `kind` tag the same way `Tool.Content`
/// in the MCP SDK itself decodes its own tagged union.
public enum ScriptRunStatus: Sendable, Hashable {
    case started(ScriptRunStarted)
    case progress(ScriptRunProgress)
    case completed(ScriptRunCompleted)
    case failed(ScriptRunFailed)
    case cancelled(ScriptRunCancelled)
    case paused(ScriptRunPaused)
    case resumed(ScriptRunResumed)
    case pauseRejected(ScriptRunPauseRejected)

    /// Whether this status is a final outcome for the run — no further `getScriptStatus` call
    /// will ever change it.
    public var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled, .paused, .pauseRejected:
            return true
        case .started, .progress, .resumed:
            return false
        }
    }
}

extension ScriptRunStatus: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)
        switch kind {
        case "scriptStarted":
            self = .started(try ScriptRunStarted(from: decoder))
        case "scriptProgress":
            self = .progress(try ScriptRunProgress(from: decoder))
        case "scriptCompleted":
            self = .completed(try ScriptRunCompleted(from: decoder))
        case "scriptFailed":
            self = .failed(try ScriptRunFailed(from: decoder))
        case "scriptCancelled":
            self = .cancelled(try ScriptRunCancelled(from: decoder))
        case "scriptPaused":
            self = .paused(try ScriptRunPaused(from: decoder))
        case "scriptResumed":
            self = .resumed(try ScriptRunResumed(from: decoder))
        case "scriptPauseRejected":
            self = .pauseRejected(try ScriptRunPauseRejected(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind,
                in: container,
                debugDescription: "Unknown script run status kind: \(kind)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .started(let value):
            try container.encode("scriptStarted", forKey: .kind)
            try value.encode(to: encoder)
        case .progress(let value):
            try container.encode("scriptProgress", forKey: .kind)
            try value.encode(to: encoder)
        case .completed(let value):
            try container.encode("scriptCompleted", forKey: .kind)
            try value.encode(to: encoder)
        case .failed(let value):
            try container.encode("scriptFailed", forKey: .kind)
            try value.encode(to: encoder)
        case .cancelled(let value):
            try container.encode("scriptCancelled", forKey: .kind)
            try value.encode(to: encoder)
        case .paused(let value):
            try container.encode("scriptPaused", forKey: .kind)
            try value.encode(to: encoder)
        case .resumed(let value):
            try container.encode("scriptResumed", forKey: .kind)
            try value.encode(to: encoder)
        case .pauseRejected(let value):
            try container.encode("scriptPauseRejected", forKey: .kind)
            try value.encode(to: encoder)
        }
    }
}

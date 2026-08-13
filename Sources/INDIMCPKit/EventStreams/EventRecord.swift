import Foundation
import MCP

/// One durably-logged event, as returned by `getEvents` — the original `kind`-tagged event plus
/// its log metadata.
///
/// Mirrors INDIMCP-server's `EventRecord` (`event_log.py`). `payload` is kept as a raw `Value`
/// rather than decoded into `IndiEvent`/`ScriptRunStatus` here, since which shape applies depends
/// on `stream` (`.messages` → `IndiEvent`, `.scripts` → `ScriptRunStatus`) and a caller that only
/// wants one stream's events shouldn't have to satisfy both types' decoding requirements just to
/// read this record's bookkeeping fields (`id`/`occurredAt`/...). Decode `payload` yourself once
/// you know which stream you asked for — see `IndiEvent`/`ScriptRunStatus`'s own `Codable`
/// conformance, which both already expect exactly this `kind`-tagged shape.
public struct EventRecord: Codable, Sendable, Hashable {
    public let id: Int
    public let stream: EventStream
    public let device: String?
    public let runId: String?
    public let occurredAt: String
    public let payload: Value

    public init(
        id: Int,
        stream: EventStream,
        device: String?,
        runId: String?,
        occurredAt: String,
        payload: Value
    ) {
        self.id = id
        self.stream = stream
        self.device = device
        self.runId = runId
        self.occurredAt = occurredAt
        self.payload = payload
    }
}

extension EventRecord {
    /// Decodes `payload` as `IndiEvent` — only meaningful when `stream == .messages`; throws a
    /// decoding error otherwise, since a scripting-layer payload won't match `IndiEvent`'s shape.
    public func decodedMessage() throws -> IndiEvent {
        try decodeValue(IndiEvent.self, from: payload)
    }

    /// Decodes `payload` as `ScriptRunStatus` — only meaningful when `stream == .scripts`; throws
    /// a decoding error otherwise.
    public func decodedScriptStatus() throws -> ScriptRunStatus {
        try decodeValue(ScriptRunStatus.self, from: payload)
    }
}

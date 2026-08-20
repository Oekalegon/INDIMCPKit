import Foundation
import MCP

/// One durably-logged event, as returned by `getEvents` — the original `kind`-tagged event plus
/// its log metadata.
///
/// Mirrors INDIMCP-server's `EventRecord` (`event_log.py`). `payload` is kept as a raw `Value`
/// rather than decoded into `IndiEvent`/`ScriptRunStatus`/`ConnectionEvent` here, since which
/// shape applies depends on `stream` (`.messages` → `IndiEvent`, `.scripts` → `ScriptRunStatus`,
/// `.connection` → `ConnectionEvent`) and a caller that only wants one stream's events shouldn't
/// have to satisfy every type's decoding requirements just to read this record's bookkeeping
/// fields (`id`/`occurredAt`/...). Decode `payload` yourself once you know which stream you
/// asked for — see `IndiEvent`/`ScriptRunStatus`/`ConnectionEvent`'s own `Codable` conformance,
/// which all already expect exactly this `kind`-tagged shape.
public struct EventRecord: Codable, Sendable, Hashable {
    /// The durable event log's row id for this event, unique within the log.
    public let id: Int
    /// Which event-log stream this record belongs to.
    public let stream: EventStream
    /// The INDI device this event pertains to, if any.
    public let device: String?
    /// The script run this event pertains to, if any.
    public let runId: String?
    /// The `target` a `.connection`-stream event is about (see `ConnectionEvent.target`) — `nil`
    /// for a `.messages`/`.scripts` record, and also `nil` for a `.connection` record whose row
    /// predates `target` existing server-side (INDIMCP-57's schema migration; same "column added
    /// after the table already existed" story as `FrameMetadata.checksumSha256`).
    public let target: String?
    /// When the server recorded this event.
    public let occurredAt: String
    /// The event's raw payload — decode with `decodedMessage()` or `decodedScriptStatus()`
    /// depending on `stream`.
    public let payload: Value

    /// Creates a new event record.
    public init(
        id: Int,
        stream: EventStream,
        device: String?,
        runId: String?,
        target: String?,
        occurredAt: String,
        payload: Value
    ) {
        self.id = id
        self.stream = stream
        self.device = device
        self.runId = runId
        self.target = target
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

    /// Decodes `payload` as `ConnectionEvent` — only meaningful when `stream == .connection`;
    /// throws a decoding error otherwise.
    public func decodedConnectionEvent() throws -> ConnectionEvent {
        try decodeValue(ConnectionEvent.self, from: payload)
    }
}

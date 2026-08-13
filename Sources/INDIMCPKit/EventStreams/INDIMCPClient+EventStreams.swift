import Foundation
import MCP

extension INDIMCPClient {
    /// Subscribes to the INDI messaging-layer event stream (`indi://messages`), optionally scoped
    /// to one `device`, and returns a stream of the resource's rolling window of recent events —
    /// newest first, per the server's own convention — yielded once immediately and again every
    /// time the server notifies the resource changed.
    ///
    /// This is the live, best-effort channel described in `docs/Design.md#event-streams` — it's
    /// "notify me while I'm connected," not a resilience mechanism. A client that was offline
    /// should not assume it received every event it missed; use `getEvents(stream: .messages, ...)`
    /// against the durable event log to catch up after reconnecting instead. There's also no
    /// per-event identity in this rolling window to dedupe against (unlike `EventRecord.id` from
    /// `getEvents`) — each yielded array is simply "here's the current window," which may repeat
    /// events you've already seen.
    ///
    /// The returned stream keeps running until its consumer stops iterating it (e.g. the
    /// enclosing `Task` is cancelled) or an error is thrown — see `subscribeToResourceUpdates`'s
    /// doc comment for the one caveat around unsubscribing.
    public func messageEvents(device: String? = nil) -> AsyncThrowingStream<[IndiEvent], Error> {
        subscribeToResourceUpdates(
            uri: Self.messagesURI(device: device),
            decoding: MessagesEnvelope.self,
            transform: \.events
        )
    }

    /// Subscribes to the scripting-layer event stream (`indi://scripts`), optionally scoped to one
    /// `runId` — same shape and caveats as `messageEvents`.
    public func scriptEvents(runId: String? = nil) -> AsyncThrowingStream<[ScriptRunStatus], Error> {
        subscribeToResourceUpdates(
            uri: Self.scriptsURI(runId: runId),
            decoding: ScriptsEnvelope.self,
            transform: \.events
        )
    }

    /// `indi://messages` resource content: `{"events": [...]}`, per `docs/Design.md#event-streams`.
    private struct MessagesEnvelope: Decodable, Sendable {
        let events: [IndiEvent]
    }

    /// `indi://scripts` resource content, same envelope shape as `MessagesEnvelope`.
    private struct ScriptsEnvelope: Decodable, Sendable {
        let events: [ScriptRunStatus]
    }

    /// Matches INDIMCP-server's `event_streams.messages_uri` exactly, including its percent-
    /// encoding of `device` (RFC 3986 unreserved characters only left unescaped) — the server's
    /// single-segment `indi://messages/{device}` resource template can't match a `device` name
    /// containing an unencoded `/`, so this has to agree with the server on the same encoding or
    /// a device name with special characters would silently subscribe to the wrong (or no) URI.
    static func messagesURI(device: String?) -> String {
        guard let device else { return "indi://messages" }
        return "indi://messages/\(percentEncoded(device))"
    }

    /// Matches INDIMCP-server's `event_streams.scripts_uri` — see `messagesURI`.
    static func scriptsURI(runId: String?) -> String {
        guard let runId else { return "indi://scripts" }
        return "indi://scripts/\(percentEncoded(runId))"
    }

    private static func percentEncoded(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

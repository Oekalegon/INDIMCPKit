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

    /// Subscribes to the scripting-layer event stream (`indi://mcp-server/scripts`), optionally
    /// scoped to one `runId` — same shape and caveats as `messageEvents`.
    ///
    /// Renamed server-side from the top-level `indi://scripts` by INDIMCP-57 (a clean rename, no
    /// server-side back-compat) — see `EventStream`'s doc comment.
    public func scriptEvents(runId: String? = nil) -> AsyncThrowingStream<[ScriptRunStatus], Error> {
        subscribeToResourceUpdates(
            uri: Self.scriptsURI(runId: runId),
            decoding: ScriptsEnvelope.self,
            transform: \.events
        )
    }

    /// Subscribes to the connection-lifecycle event stream (`indi://mcp-server/connection`,
    /// INDIMCP-57), optionally scoped to one `target` — same shape and caveats as
    /// `messageEvents`. Covers connection changes for this server's own link to `indiserver`
    /// (`target: "server"`), the `indiserver` process (`target: "indiserver"`), and individual
    /// driver processes (`target`: that driver's catalog label) — see `ConnectionEvent`.
    ///
    /// - Parameter target: Scopes the stream to one connection target, if given; `nil` for every
    ///   target.
    /// - Returns: A stream yielding the resource's rolling window of recent connection events,
    ///   newest first, once immediately and again on every server-side update.
    public func connectionEvents(target: String? = nil) -> AsyncThrowingStream<[ConnectionEvent], Error> {
        subscribeToResourceUpdates(
            uri: Self.connectionURI(target: target),
            decoding: ConnectionEnvelope.self,
            transform: \.events
        )
    }

    /// `indi://messages` resource content: `{"events": [...]}`, per `docs/Design.md#event-streams`.
    private struct MessagesEnvelope: Decodable, Sendable {
        let events: [IndiEvent]
    }

    /// `indi://mcp-server/scripts` resource content, same envelope shape as `MessagesEnvelope`.
    private struct ScriptsEnvelope: Decodable, Sendable {
        let events: [ScriptRunStatus]
    }

    /// `indi://mcp-server/connection` resource content, same envelope shape as `MessagesEnvelope`.
    private struct ConnectionEnvelope: Decodable, Sendable {
        let events: [ConnectionEvent]
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

    /// Matches INDIMCP-server's `event_streams.scripts_uri` — see `messagesURI`. Renamed
    /// server-side from `indi://scripts` by INDIMCP-57.
    static func scriptsURI(runId: String?) -> String {
        guard let runId else { return "indi://mcp-server/scripts" }
        return "indi://mcp-server/scripts/\(percentEncoded(runId))"
    }

    /// Matches INDIMCP-server's `event_streams.connection_uri` — see `messagesURI`. `target` is
    /// `"server"`/`"indiserver"`/a driver label; percent-encoded the same way `device`/`runId`
    /// already are, since a driver's catalog label is caller-supplied text with no guarantee it's
    /// URL-safe as-is.
    static func connectionURI(target: String?) -> String {
        guard let target else { return "indi://mcp-server/connection" }
        return "indi://mcp-server/connection/\(percentEncoded(target))"
    }

    /// ASCII-only unreserved set (RFC 3986), matching Python's `quote(safe="")` exactly.
    /// `CharacterSet.alphanumerics` would be the wrong building block here — it's Unicode-inclusive
    /// (every Unicode letter/digit, not just `A-Za-z0-9`), while `quote`'s default `safe` set is
    /// ASCII-only; anything outside it, non-ASCII letters included, gets percent-encoded as UTF-8
    /// bytes. A device name like `"Café Simulator"` would otherwise encode differently here than
    /// on the server, and `event_streams.py` matches subscriptions by exact URI string — a
    /// mismatched encoding means that device's live messages silently never arrive, with nothing
    /// to point at why.
    private static func percentEncoded(_ value: String) -> String {
        let allowed = CharacterSet(
            charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
        )
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

import MCP

extension INDIMCPClient {
    /// Catches up on missed `indi://messages`/`indi://scripts` events from the durable event log,
    /// oldest first.
    ///
    /// Unlike the live `resources/subscribe` channel (`messageEvents`/`scriptEvents` below —
    /// best-effort, live-only), this queries the server's durable SQLite log every event is also
    /// written to, so a client that was disconnected can reliably fetch what it missed rather than
    /// assuming the live subscription caught everything. Pass `since` as the `occurredAt` of the
    /// last event you actually saw — the filter is inclusive (that same event comes back again
    /// rather than being excluded), so dedupe by `id` if you call this repeatedly. Events older
    /// than a day are purged server-side, so this isn't a substitute for permanent history.
    public func getEvents(
        stream: EventStream,
        device: String? = nil,
        runId: String? = nil,
        since: String? = nil
    ) async throws -> [EventRecord] {
        var arguments: [String: Value] = ["stream": .string(stream.rawValue)]
        if let device {
            arguments["device"] = .string(device)
        }
        if let runId {
            arguments["run_id"] = .string(runId)
        }
        if let since {
            arguments["since"] = .string(since)
        }
        return try await callToolList("get_events", arguments: arguments, decoding: EventRecord.self)
    }
}

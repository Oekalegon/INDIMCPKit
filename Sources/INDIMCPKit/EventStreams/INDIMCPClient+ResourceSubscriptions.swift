import Foundation
import MCP

extension INDIMCPClient {
    /// Subscribes to the resource at `uri` and returns a stream that yields its content — decoded
    /// as `Envelope` then passed through `transform` (so a caller can unwrap e.g. `{"events":
    /// [...]}` down to the bare `[IndiEvent]`/`[ScriptRunStatus]` it actually wants) — once
    /// immediately after subscribing and again every time the server sends
    /// `notifications/resources/updated` for it. See `messageEvents`/`scriptEvents`, the typed,
    /// INDI-specific callers of this.
    ///
    /// The underlying MCP client has no way to unregister a notification handler once registered
    /// (`onNotification` only ever appends) — the closure this creates lingers in memory for the
    /// lifetime of this `INDIMCPClient`, even after the stream's consumer stops iterating and
    /// `resources/unsubscribe` has been sent. It becomes an inert no-op at that point (it checks
    /// `message.params.uri == uri`, and the server won't publish further updates for an
    /// unsubscribed URI), so this is safe for the handful of long-lived streams a typical app
    /// opens, but not a good fit for a caller creating and discarding many short-lived ones.
    func subscribeToResourceUpdates<Envelope: Decodable & Sendable, Output: Sendable>(
        uri: String,
        decoding envelopeType: Envelope.Type,
        transform: @escaping @Sendable (Envelope) -> Output
    ) -> AsyncThrowingStream<Output, Error> {
        AsyncThrowingStream { continuation in
            // Coalesces re-reads triggered by `onNotification` so at most one `readResourceContent`
            // call is ever in flight for this subscription — see `readAndYield`'s own comment for
            // why letting them run concurrently and unordered is unsafe.
            let coalescer = ReadCoalescer()

            // Detached from whatever called it (the initial read below runs it inline from
            // `task`'s own body, never from `Client`'s receive loop; the notification handler
            // below always runs it from a freshly spawned `Task`) — `shouldStartReading`/
            // `finishedReading` are plain actor hops, not network round-trips, so awaiting them
            // here never risks the deadlock `readAndYield`'s own comment describes.
            @Sendable
            func readAndYield() async {
                guard await coalescer.shouldStartReading() else { return }
                repeat {
                    do {
                        let envelope = try await self.readResourceContent(uri: uri, decoding: Envelope.self)
                        continuation.yield(transform(envelope))
                    } catch {
                        continuation.finish(throwing: error)
                        return
                    }
                } while await coalescer.finishedReading()
            }

            let task = Task {
                do {
                    // Registered before subscribing/reading, not after: a notification that
                    // arrived in the gap between the initial read and registering the handler
                    // would otherwise be silently missed until the *next* one, which for a
                    // stream that only updates once or twice more could mean missing its
                    // terminal state entirely. Registering first costs nothing — the server
                    // can't publish a notification for a URI this session hasn't subscribed to
                    // yet, so there's no risk of the handler firing before it's meaningful.
                    await self.client.onNotification(ResourceUpdatedNotification.self) { message in
                        guard message.params.uri == uri else { return }
                        // Must not `await` the read inline: the swift-sdk's `Client` runs one
                        // single task that reads every incoming message (responses included) and
                        // dispatches each to its notification handlers sequentially, awaiting each
                        // handler before reading the next message (`Client.handleMessage`). This
                        // handler issuing its own request and awaiting *that* request's response
                        // inline would deadlock that same task forever — the response can only
                        // ever be delivered by the very task this handler is currently blocking.
                        // Detaching lets the handler return immediately, so the receive loop stays
                        // free to deliver this read's response (and everything after it).
                        //
                        // Routed through `readAndYield`/`coalescer`, not a bare `Task { await
                        // self.readResourceContent(...) }`, so a burst of several notifications
                        // arriving close together can't run their reads concurrently: each fetches
                        // the *current* window at whatever moment it actually runs, so an earlier
                        // notification's read finishing *after* a later one's would yield a stale
                        // snapshot last, silently reverting `ObservableDevice.properties` to an
                        // older state. Coalescing keeps reads serialized — at most one in flight,
                        // with any notification that arrives mid-read simply triggering one more
                        // read afterward rather than a concurrent one.
                        Task { await readAndYield() }
                    }
                    try await self.client.subscribeToResource(uri: uri)
                    await readAndYield()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { [client] _ in
                task.cancel()
                Task { await Self.unsubscribeFromResource(uri: uri, client: client) }
            }
        }
    }

    /// Serializes `subscribeToResourceUpdates`'s re-reads to at most one in flight at a time —
    /// see that function's `readAndYield` for why concurrent, unordered reads are unsafe here.
    ///
    /// `internal` rather than `private`, purely so its coalescing behavior is directly
    /// unit-testable (`@testable import`) without needing a live server or a fake transport — same
    /// reasoning as `ObservableDevice.apply(_:)`'s own access level.
    actor ReadCoalescer {
        private var isReading = false
        private var rereadRequested = false

        /// `true` if the caller should actually read now. `false` means a read is already in
        /// flight; this call's worth of "something changed" is folded into that read's own
        /// follow-up loop instead of starting a second, concurrent one.
        func shouldStartReading() -> Bool {
            guard !isReading else {
                rereadRequested = true
                return false
            }
            isReading = true
            return true
        }

        /// Call once a read completes. `true` means another notification arrived while it was in
        /// flight and the caller should read again before considering things settled; `false`
        /// means nothing new arrived and the caller is done.
        func finishedReading() -> Bool {
            guard rereadRequested else {
                isReading = false
                return false
            }
            rereadRequested = false
            return true
        }
    }

    /// Sends `resources/unsubscribe` for `uri` and waits for the round-trip to complete.
    ///
    /// `subscribeToResourceUpdates`'s own `onTermination` cleanup already does this, but as a
    /// detached, un-awaited `Task` — fine as a backstop for a stream whose consumer simply stops
    /// iterating, but useless to a caller that needs the server to have actually forgotten this
    /// subscription *before* it does anything else, such as re-subscribing to the exact same
    /// `uri` (see `ObservableDevice.stop()`). Without waiting here, a fresh subscribe can race
    /// this unsubscribe over the wire; if the unsubscribe lands second, it silently discards the
    /// new subscription from the server's subscriber set — the client believes it's subscribed
    /// but never receives another update.
    func unsubscribeFromResource(uri: String) async {
        await Self.unsubscribeFromResource(uri: uri, client: client)
    }

    private static func unsubscribeFromResource(uri: String, client: Client) async {
        // ResourceUnsubscribe.Parameters has no public memberwise initializer (the swift-sdk
        // module only synthesizes one at `internal` access, unlike its Codable init(from:), which
        // does follow the type's own `public` access) — going through Decodable is the only way
        // to construct one from outside that module.
        guard let params = try? JSONDecoder().decode(
            ResourceUnsubscribe.Parameters.self,
            from: JSONEncoder().encode(["uri": uri])
        ) else {
            return
        }
        _ = try? await client.send(ResourceUnsubscribe.request(params)).value
    }

    private func readResourceContent<Output: Decodable & Sendable>(
        uri: String,
        decoding type: Output.Type
    ) async throws -> Output {
        guard let text = try await client.readResource(uri: uri).first?.text else {
            throw INDIMCPClientError.missingResourceContent(uri: uri)
        }
        return try JSONDecoder().decode(Output.self, from: Data(text.utf8))
    }
}

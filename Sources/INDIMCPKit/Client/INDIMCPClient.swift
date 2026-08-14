import Foundation
import MCP

/// A connection to a single INDIMCP-server instance.
///
/// Wraps the MCP session (transport + protocol handshake) and exposes a typed
/// `callTool` used by the device-type abstractions (`Mount`, `Camera`, ...) and server-management
/// calls built on top of it. INDIMCPKit only talks Streamable HTTP, matching the server's
/// network-reachable deployment mode — see the INDIMCP-server deployment docs for why `stdio` is
/// local-testing-only and not a supported target here.
public final class INDIMCPClient: Sendable {
    private let client: Client
    private let transport: HTTPClientTransport
    private let endpoint: URL

    /// Creates a client pointed at an INDIMCP-server instance. Call `connect()` before issuing
    /// any tool calls.
    ///
    /// - Parameters:
    ///   - endpoint: The server's Streamable HTTP endpoint, e.g. `http://telescope.local:8000/mcp`.
    ///   - clientName: Reported to the server during the MCP handshake.
    ///   - clientVersion: Reported to the server during the MCP handshake.
    public init(
        endpoint: URL,
        clientName: String = "INDIMCPKit",
        clientVersion: String = "0.1.0"
    ) {
        self.client = Client(name: clientName, version: clientVersion)
        // `HTTPClientTransport.send(_:)` doesn't return for a given request until that request's
        // own SSE response stream closes — if INDIMCP-server (or an intermediary) leaves those
        // per-request streams open longer than it needs to, each concurrent tool call quietly
        // pins one of `URLSession`'s connections-per-host slots for its whole lifetime. The
        // default `.default` configuration caps that at 6, which a normal app session blows
        // through almost immediately (server start, messaging start, rig list, then the Server
        // tab's own 5 concurrent status calls) — every call after the 6th then queues forever
        // waiting for a free connection, with nothing to time it out. Raising the cap well above
        // anything this app issues concurrently is a pragmatic mitigation for that; the real fix,
        // if this diagnosis holds, belongs in INDIMCP-server's response-stream lifecycle.
        let configuration = URLSessionConfiguration.default
        configuration.httpMaximumConnectionsPerHost = 32
        self.transport = HTTPClientTransport(endpoint: endpoint, configuration: configuration)
        self.endpoint = endpoint
    }

    /// Connects to the server and performs the MCP initialization handshake.
    @discardableResult
    public func connect() async throws -> Initialize.Result {
        try await client.connect(transport: transport)
    }

    /// Closes the connection. The client can't be reused after this; create a new one to
    /// reconnect.
    public func disconnect() async {
        await client.disconnect()
    }

    /// Calls a tool on the server and decodes its `structuredContent` into `Output`.
    ///
    /// Every standard INDIMCP-server tool returns a typed (Pydantic/TypedDict) result, which
    /// FastMCP surfaces as `structuredContent` on the `tools/call` response — this is what gets
    /// decoded, not the human-readable `content` text block also present on the response.
    ///
    /// Only for tools whose Python return type is itself an object (a `TypedDict`/`BaseModel`).
    /// A tool that returns a bare `list[...]` needs `callToolList(_:arguments:decoding:)` instead
    /// — see its doc comment for why.
    func callTool<Output: Decodable & Sendable>(
        _ name: String,
        arguments: [String: Value]? = nil,
        decoding type: Output.Type
    ) async throws -> Output {
        let structuredContent = try await structuredContent(forToolNamed: name, arguments: arguments)
        return try Self.decode(Output.self, from: structuredContent)
    }

    /// Calls a tool whose Python return type is a bare `list[...]` and decodes its elements.
    ///
    /// FastMCP can't put a JSON array directly in `structuredContent` — the MCP spec requires
    /// `structuredContent` to be a JSON *object* matching the tool's declared output schema — so
    /// it wraps a bare list return value as `{"result": [...]}` instead. This unwraps that
    /// convention; a tool that already returns an object containing its own array field doesn't
    /// need this; use `callTool(_:arguments:decoding:)` and give it a wrapper type instead.
    func callToolList<Output: Decodable & Sendable>(
        _ name: String,
        arguments: [String: Value]? = nil,
        decoding type: Output.Type
    ) async throws -> [Output] {
        try await callToolUnwrappingResult(name, arguments: arguments, decoding: [Output].self)
    }

    /// Calls a tool whose Python return type is a `Union[...]` (e.g. `ScriptRunStatus`) and
    /// decodes the discriminated result.
    ///
    /// Same reasoning as `callToolList`: a `Union` isn't a single object schema either, so
    /// FastMCP wraps it as `{"result": ...}` just like a bare list — confirmed against the real
    /// server's wire format for `get_script_status`/`cancel_script`/`pause_script`/
    /// `resume_script`. `Output` here is expected to be a manually `Decodable` discriminated-union
    /// type (switching on a `kind`/similar tag), not a plain struct.
    func callToolUnion<Output: Decodable & Sendable>(
        _ name: String,
        arguments: [String: Value]? = nil,
        decoding type: Output.Type
    ) async throws -> Output {
        try await callToolUnwrappingResult(name, arguments: arguments, decoding: Output.self)
    }

    private func callToolUnwrappingResult<Output: Decodable & Sendable>(
        _ name: String,
        arguments: [String: Value]?,
        decoding type: Output.Type
    ) async throws -> Output {
        let structuredContent = try await structuredContent(forToolNamed: name, arguments: arguments)
        return try Self.decode(ResultWrapper<Output>.self, from: structuredContent).result
    }

    private struct ResultWrapper<Wrapped: Decodable & Sendable>: Decodable, Sendable {
        let result: Wrapped
    }

    private static func decode<Output: Decodable>(_ type: Output.Type, from value: Value) throws -> Output {
        try decodeValue(type, from: value)
    }

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
                        Task {
                            do {
                                let envelope = try await self.readResourceContent(uri: uri, decoding: Envelope.self)
                                continuation.yield(transform(envelope))
                            } catch {
                                continuation.finish(throwing: error)
                            }
                        }
                    }
                    try await self.client.subscribeToResource(uri: uri)
                    let envelope = try await self.readResourceContent(uri: uri, decoding: Envelope.self)
                    continuation.yield(transform(envelope))
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

    /// Substitutes this client's own connection host for `url`'s host — used by `downloadFrame`
    /// on a frame's `downloadUrl`.
    ///
    /// INDIMCP-server computes `downloadUrl` from its own `socket.gethostname()` (an mDNS
    /// `.local` name, confirmed against the server's `_frame_download_url` doc comment), which
    /// isn't reliably resolvable from every client's network — mDNS can be disabled, blocked
    /// across subnets, or simply not configured — even though the exact same server is already
    /// reachable at whatever host this client used to connect via MCP in the first place (`endpoint`).
    /// Swapping in that already-proven-reachable host, while keeping `url`'s own scheme/port/path
    /// exactly as the server returned them, sidesteps hostname-resolution failures entirely
    /// without needing any server-side change. A no-op if the hosts already match.
    func reachableURL(for url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let endpointHost = endpoint.host,
            components.host != endpointHost
        else {
            return url
        }
        components.host = endpointHost
        return components.url ?? url
    }

    private func structuredContent(forToolNamed name: String, arguments: [String: Value]?) async throws -> Value {
        let context: RequestContext<CallTool.Result> = try await client.callTool(
            name: name, arguments: arguments
        )
        let result = try await context.value

        if result.isError == true {
            throw INDIMCPClientError.toolCallFailed(
                tool: name,
                message: Self.errorMessage(from: result.content)
            )
        }

        guard let structuredContent = result.structuredContent else {
            throw INDIMCPClientError.missingStructuredContent(tool: name)
        }

        return structuredContent
    }

    private static func errorMessage(from content: [Tool.Content]) -> String {
        let text = content.compactMap { block -> String? in
            if case .text(let text, _, _) = block { return text }
            return nil
        }.joined(separator: "\n")
        return text.isEmpty ? "(no error message provided)" : text
    }
}

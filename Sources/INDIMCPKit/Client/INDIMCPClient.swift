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
    /// Internal (not `private`) so the `EventStreams`/`Frames` extension files that implement
    /// resource-subscription and frame-download support can reach it. Callers outside this file
    /// should still go through `callTool`/`callToolList`/`callToolUnion`, not `client` directly,
    /// to keep tool-call error-shape handling (`structuredContent(forToolNamed:arguments:)`)
    /// centralized rather than reimplemented per call site.
    let client: Client
    /// The Streamable HTTP transport constructed in `init` and handed to `client` in
    /// `connect()`. Stored so it survives between those two calls — `Client` itself retains it
    /// for the connection's actual lifetime once `connect(transport:)` runs.
    private let transport: HTTPClientTransport
    /// Internal (not `private`) for the same reason as `client` — `Frames/INDIMCPClient+
    /// FrameDownload.swift`'s `reachableURL(for:)` needs this client's own connection host.
    let endpoint: URL

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

    /// Shared implementation behind `callToolList`/`callToolUnion`: calls `name`, then decodes
    /// its `structuredContent` as `{"result": Output}` and returns the unwrapped `result`.
    private func callToolUnwrappingResult<Output: Decodable & Sendable>(
        _ name: String,
        arguments: [String: Value]?,
        decoding type: Output.Type
    ) async throws -> Output {
        let structuredContent = try await structuredContent(forToolNamed: name, arguments: arguments)
        return try Self.decode(ResultWrapper<Output>.self, from: structuredContent).result
    }

    /// Matches FastMCP's `{"result": ...}` wrapping of a bare-list or `Union` tool return value —
    /// see `callToolUnwrappingResult`.
    private struct ResultWrapper<Wrapped: Decodable & Sendable>: Decodable, Sendable {
        let result: Wrapped
    }

    /// Decodes `value` (already-parsed `structuredContent`) as `Output`, going through
    /// `decodeValue` since `Value` isn't itself a `Decoder`.
    private static func decode<Output: Decodable>(_ type: Output.Type, from value: Value) throws -> Output {
        try decodeValue(type, from: value)
    }

    /// Calls tool `name`, throwing `INDIMCPClientError.toolCallFailed`/`.missingStructuredContent`
    /// for the two ways a `tools/call` response can fail to carry a usable typed result, and
    /// returning the raw `structuredContent` otherwise for the caller to decode.
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

    /// Joins every text block in a failed tool call's `content` into one message, or a
    /// placeholder if the server didn't provide any text content.
    private static func errorMessage(from content: [Tool.Content]) -> String {
        let text = content.compactMap { block -> String? in
            if case .text(let text, _, _) = block { return text }
            return nil
        }.joined(separator: "\n")
        return text.isEmpty ? "(no error message provided)" : text
    }
}

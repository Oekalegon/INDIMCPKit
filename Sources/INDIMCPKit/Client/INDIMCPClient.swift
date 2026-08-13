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
        self.transport = HTTPClientTransport(endpoint: endpoint)
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
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(Output.self, from: data)
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

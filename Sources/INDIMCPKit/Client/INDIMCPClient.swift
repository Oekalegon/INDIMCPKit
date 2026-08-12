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
    func callTool<Output: Decodable & Sendable>(
        _ name: String,
        arguments: [String: Value]? = nil,
        decoding type: Output.Type
    ) async throws -> Output {
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

        let data = try JSONEncoder().encode(structuredContent)
        return try JSONDecoder().decode(Output.self, from: data)
    }

    private static func errorMessage(from content: [Tool.Content]) -> String {
        let text = content.compactMap { block -> String? in
            if case .text(let text, _, _) = block { return text }
            return nil
        }.joined(separator: "\n")
        return text.isEmpty ? "(no error message provided)" : text
    }
}

/// Errors surfaced by `INDIMCPClient` when talking to an INDIMCP-server instance.
public enum INDIMCPClientError: Error, Sendable {
    /// The server's `tools/call` response set `isError`, meaning the tool itself reported a
    /// failure rather than the transport/protocol failing.
    case toolCallFailed(tool: String, message: String)

    /// The tool call succeeded but the response carried no `structuredContent`, so it can't be
    /// decoded into a typed Swift result. Every standard INDIMCP-server tool is expected to
    /// return structured content; a missing one usually means a version mismatch between this
    /// kit and the server it's talking to.
    case missingStructuredContent(tool: String)
}

extension INDIMCPClientError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .toolCallFailed(let tool, let message):
            return "INDIMCP-server tool '\(tool)' failed: \(message)"
        case .missingStructuredContent(let tool):
            return "INDIMCP-server tool '\(tool)' returned no structured content to decode"
        }
    }
}

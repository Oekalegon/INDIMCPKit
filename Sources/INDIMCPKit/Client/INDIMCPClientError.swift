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

    /// `waitForTerminalStatus(runId:)` polled `attempts` times without the run ever reaching a
    /// terminal status.
    case pollingTimedOut(runId: String, attempts: Int)

    /// A `resources/read` on `uri` (`messageEvents`/`scriptEvents`'s initial read, or a re-read
    /// triggered by a `notifications/resources/updated`) returned no text content to decode.
    /// Every `indi://messages`/`indi://scripts` resource is expected to return one JSON text
    /// content item; a missing one usually means a version mismatch between this kit and the
    /// server it's talking to, the same way `missingStructuredContent` does for tool calls.
    case missingResourceContent(uri: String)
}

extension INDIMCPClientError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .toolCallFailed(let tool, let message):
            return "INDIMCP-server tool '\(tool)' failed: \(message)"
        case .missingStructuredContent(let tool):
            return "INDIMCP-server tool '\(tool)' returned no structured content to decode"
        case .pollingTimedOut(let runId, let attempts):
            return "Run '\(runId)' did not reach a terminal status after \(attempts) polling attempt(s)"
        case .missingResourceContent(let uri):
            return "INDIMCP-server resource '\(uri)' returned no text content to decode"
        }
    }
}

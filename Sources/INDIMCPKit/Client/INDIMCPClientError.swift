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

    /// A `resources/read` on `uri` (`messageEvents`/`scriptEvents`/`connectionEvents`'s initial
    /// read, or a re-read triggered by a `notifications/resources/updated`) returned no text
    /// content to decode. Every `indi://messages`/`indi://mcp-server` resource is expected to
    /// return one JSON text content item; a missing one usually means a version mismatch between
    /// this kit and the server it's talking to, the same way `missingStructuredContent` does for
    /// tool calls.
    case missingResourceContent(uri: String)

    /// `downloadFrame` was asked to download a frame whose `downloadUrl` is `nil` — the server
    /// has no HTTP listener to build one from (running under the `stdio` transport). There's
    /// nothing to retry here; a frame captured by a `stdio`-transport server can't be downloaded
    /// over HTTP at all.
    case frameNotDownloadable(frameId: String)

    /// `downloadFrame`'s `GET` on the frame's `downloadUrl` returned a non-2xx HTTP status —
    /// most commonly 404 (the frame was deleted server-side between listing it and downloading
    /// it) or a network-level proxy/gateway error, not an MCP protocol error.
    case frameDownloadFailed(frameId: String, statusCode: Int)

    /// `deleteAllFrames(acknowledgingPermanentDataLoss:)` was called with `false` — refused before
    /// touching the server at all, since this call can delete frames nothing has copied anywhere
    /// else yet.
    case allFramesDeletionNotAcknowledged
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
        case .frameNotDownloadable(let frameId):
            return "Frame '\(frameId)' has no downloadUrl (server has no HTTP listener)"
        case .frameDownloadFailed(let frameId, let statusCode):
            return "Downloading frame '\(frameId)' failed with HTTP status \(statusCode)"
        case .allFramesDeletionNotAcknowledged:
            return "deleteAllFrames requires acknowledgingPermanentDataLoss: true"
        }
    }
}

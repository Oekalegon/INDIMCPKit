import MCP

/// INDI's conventional default port for `indiserver`, matching INDIMCP-server's `INDI_PORT`.
public let defaultINDIServerPort = 7624

extension INDIMCPClient {
    /// Starts `indiserver` on the given port, restarting it first if it's already running.
    public func startINDIServer(port: Int = defaultINDIServerPort) async throws -> IndiServerStatus {
        try await callTool(
            "start_indi_server",
            arguments: ["port": .int(port)],
            decoding: IndiServerStatus.self
        )
    }

    /// Stops the running `indiserver` process.
    public func stopINDIServer() async throws -> IndiServerStatus {
        try await callTool("stop_indi_server", decoding: IndiServerStatus.self)
    }

    /// Restarts `indiserver`, keeping its current port unless a new one is given.
    public func restartINDIServer(port: Int? = nil) async throws -> IndiServerStatus {
        let arguments: [String: Value]? = port.map { ["port": .int($0)] }
        return try await callTool(
            "restart_indi_server",
            arguments: arguments,
            decoding: IndiServerStatus.self
        )
    }

    /// Reports whether `indiserver` is running, and on which port.
    public func getINDIServerStatus() async throws -> IndiServerStatus {
        try await callTool("get_indi_server_status", decoding: IndiServerStatus.self)
    }
}

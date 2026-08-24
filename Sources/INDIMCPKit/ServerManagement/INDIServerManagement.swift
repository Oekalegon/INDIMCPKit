import MCP

/// INDI's conventional default port for `indiserver`, matching INDIMCP-server's `INDI_PORT`.
public let defaultINDIServerPort = 7624

extension INDIMCPClient {
    /// `manage_indi_infra(component: "server", ...)`, shared by the three lifecycle methods below
    /// — replaces the old dedicated `start_indi_server`/`stop_indi_server`/`restart_indi_server`
    /// tools (INDIMCP-114).
    private func manageServerInfra(action: String, port: Int? = nil) async throws -> IndiServerStatus {
        var arguments: [String: Value] = ["component": .string("server"), "action": .string(action)]
        if let port {
            arguments["port"] = .int(port)
        }
        return try await callTool("manage_indi_infra", arguments: arguments, decoding: IndiServerStatus.self)
    }

    /// Starts `indiserver` on the given port, restarting it first if it's already running.
    public func startINDIServer(port: Int = defaultINDIServerPort) async throws -> IndiServerStatus {
        try await manageServerInfra(action: "start", port: port)
    }

    /// Stops the running `indiserver` process.
    public func stopINDIServer() async throws -> IndiServerStatus {
        try await manageServerInfra(action: "stop")
    }

    /// Restarts `indiserver`, keeping its current port unless a new one is given.
    public func restartINDIServer(port: Int? = nil) async throws -> IndiServerStatus {
        try await manageServerInfra(action: "restart", port: port)
    }

    /// Reports whether `indiserver` is running, and on which port.
    public func getINDIServerStatus() async throws -> IndiServerStatus {
        try await callTool(
            "get_indi_status",
            arguments: ["component": .string("server")],
            decoding: IndiServerStatus.self
        )
    }
}

import MCP

/// INDI's conventional default port for `indiserver`, matching INDIMCP-server's `INDI_PORT`.
public let defaultINDIServerPort = 7624

extension INDIMCPClient {
    /// `manage_indi_infra(component: "server", ...)`, shared by the three lifecycle methods below
    /// — replaces the old dedicated `start_indi_server`/`stop_indi_server`/`restart_indi_server`
    /// tools (INDIMCP-114). See also `INDIDriverManagement.manageDriverInfra` and
    /// `INDIMessaging.startINDIMessaging`/`stopINDIMessaging`, the same tool's other two
    /// `component` branches.
    ///
    /// Uses `callToolUnion`, not `callTool`: `manage_indi_infra`'s declared Python return type is
    /// `IndiServerStatus | DriverStatus | MessagingStatus`, a `Union` FastMCP wraps as
    /// `{"result": ...}` — confirmed against a real server, this failed to decode
    /// (`keyNotFound("running")`) as plain `callTool` (IMCPKIT-61).
    private func manageServerInfra(action: String, port: Int? = nil) async throws -> IndiServerStatus {
        var arguments: [String: Value] = ["component": .string("server"), "action": .string(action)]
        if let port {
            arguments["port"] = .int(port)
        }
        return try await callToolUnion("manage_indi_infra", arguments: arguments, decoding: IndiServerStatus.self)
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
    ///
    /// Uses `callToolUnion`: `get_indi_status`'s declared return type,
    /// `IndiServerStatus | MessagingStatus`, is also a `Union` FastMCP wraps (IMCPKIT-61).
    public func getINDIServerStatus() async throws -> IndiServerStatus {
        try await callToolUnion(
            "get_indi_status",
            arguments: ["component": .string("server")],
            decoding: IndiServerStatus.self
        )
    }
}

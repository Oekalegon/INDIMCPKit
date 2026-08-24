import MCP

extension INDIMCPClient {
    /// Lists every INDI driver installed on the server's device, whether or not it is running.
    public func listINDIDriverCatalog() async throws -> [DriverInfo] {
        try await callToolList(
            "list_indi_drivers",
            arguments: ["scope": .string("catalog")],
            decoding: DriverInfo.self
        )
    }

    /// `manage_indi_infra(component: "driver", ...)`, shared by `startINDIDriver`/`stopINDIDriver`
    /// — replaces the old dedicated `start_indi_driver`/`stop_indi_driver` tools (INDIMCP-114). See
    /// also `INDIServerManagement.manageServerInfra` and `INDIMessaging.startINDIMessaging`/
    /// `stopINDIMessaging`, the same tool's other two `component` branches.
    private func manageDriverInfra(action: String, label: String) async throws -> DriverStatus {
        try await callTool(
            "manage_indi_infra",
            arguments: ["component": .string("driver"), "action": .string(action), "label": .string(label)],
            decoding: DriverStatus.self
        )
    }

    /// Starts the INDI driver identified by its catalog label (e.g. `"CCD Simulator"`).
    public func startINDIDriver(label: String) async throws -> DriverStatus {
        try await manageDriverInfra(action: "start", label: label)
    }

    /// Stops the running INDI driver identified by its catalog label.
    public func stopINDIDriver(label: String) async throws -> DriverStatus {
        try await manageDriverInfra(action: "stop", label: label)
    }

    /// Lists all currently running INDI drivers.
    public func listRunningINDIDrivers() async throws -> [DriverStatus] {
        try await callToolList(
            "list_indi_drivers",
            arguments: ["scope": .string("running")],
            decoding: DriverStatus.self
        )
    }
}

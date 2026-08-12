import MCP

extension INDIMCPClient {
    /// Lists every INDI driver installed on the server's device, whether or not it is running.
    public func listINDIDriverCatalog() async throws -> [DriverInfo] {
        try await callToolList("list_indi_driver_catalog", decoding: DriverInfo.self)
    }

    /// Starts the INDI driver identified by its catalog label (e.g. `"CCD Simulator"`).
    public func startINDIDriver(label: String) async throws -> DriverStatus {
        try await callTool(
            "start_indi_driver",
            arguments: ["label": .string(label)],
            decoding: DriverStatus.self
        )
    }

    /// Stops the running INDI driver identified by its catalog label.
    public func stopINDIDriver(label: String) async throws -> DriverStatus {
        try await callTool(
            "stop_indi_driver",
            arguments: ["label": .string(label)],
            decoding: DriverStatus.self
        )
    }

    /// Lists all currently running INDI drivers.
    public func listRunningINDIDrivers() async throws -> [DriverStatus] {
        try await callToolList("list_running_indi_drivers", decoding: DriverStatus.self)
    }
}

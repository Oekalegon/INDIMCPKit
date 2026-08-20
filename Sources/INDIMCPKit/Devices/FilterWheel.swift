/// A rig-scoped handle for the `filterWheel`-role component of a saved rig.
///
/// Obtained via `INDIMCPClient.filterWheel(rigId:)`, not constructed directly. See `Mount`'s doc
/// comment for the connectivity-check behavior shared by every device-type handle.
public struct FilterWheel: DeviceHandle {
    /// The MCP client this device handle was obtained from.
    public let client: INDIMCPClient
    /// The id of the rig this device handle belongs to.
    public let rigId: String
    /// The role this device handle plays within its rig.
    public let role: Role = .filterWheel

    init(client: INDIMCPClient, rigId: String) {
        self.client = client
        self.rigId = rigId
    }

    /// Selects a filter by name, matching the rig's configured `filterWheel` slots map. See
    /// `INDIMCPClient.selectFilter`'s doc comment for the reconciliation-against-the-driver
    /// behavior this triggers server-side.
    public func selectFilter(_ filterName: String) async throws -> ScriptRunStarted {
        try await client.ensureConnected(role: .filterWheel, rigId: rigId)
        return try await client.selectFilter(rigId: rigId, filterName: filterName)
    }
}

extension INDIMCPClient {
    /// A handle for rig `rigId`'s `filterWheel`-role component.
    public func filterWheel(rigId: String) -> FilterWheel {
        FilterWheel(client: self, rigId: rigId)
    }
}

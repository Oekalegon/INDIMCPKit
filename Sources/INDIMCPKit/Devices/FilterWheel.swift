/// A rig-scoped handle for the `filterWheel`-role component of a saved rig.
///
/// Obtained via `INDIMCPClient.filterWheel(rigId:)`, not constructed directly. See `Mount`'s doc
/// comment for the connectivity-check behavior shared by every device-type handle.
public struct FilterWheel: Sendable {
    private let client: INDIMCPClient
    public let rigId: String

    init(client: INDIMCPClient, rigId: String) {
        self.client = client
        self.rigId = rigId
    }

    /// Connects the rig's filter wheel device. No connectivity check first — that's the point of
    /// this call.
    public func connect() async throws -> ScriptRunStarted {
        try await client.connectDevice(rigId: rigId, role: Role.filterWheel.rawValue)
    }

    /// Disconnects the rig's filter wheel device.
    public func disconnect() async throws -> ScriptRunStarted {
        try await client.disconnectDevice(rigId: rigId, role: Role.filterWheel.rawValue)
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

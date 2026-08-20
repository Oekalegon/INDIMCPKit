/// A rig-scoped handle for the `focuser`-role component of a saved rig.
///
/// Obtained via `INDIMCPClient.focuser(rigId:)`, not constructed directly. See `Mount`'s doc
/// comment for the connectivity-check behavior shared by every device-type handle.
public struct Focuser: DeviceHandle {
    /// The MCP client this device handle was obtained from.
    public let client: INDIMCPClient
    /// The id of the rig this device handle belongs to.
    public let rigId: String
    /// The role this device handle plays within its rig.
    public let role: Role = .focuser

    init(client: INDIMCPClient, rigId: String) {
        self.client = client
        self.rigId = rigId
    }

    /// Moves the focuser to an absolute position. Checked server-side against the rig
    /// component's own `minPosition`/`maxPosition`, if declared.
    public func setFocusPosition(_ position: Int) async throws -> ScriptRunStarted {
        try await client.ensureConnected(role: .focuser, rigId: rigId)
        return try await client.setFocusPosition(rigId: rigId, position: position)
    }
}

extension INDIMCPClient {
    /// A handle for rig `rigId`'s `focuser`-role component.
    public func focuser(rigId: String) -> Focuser {
        Focuser(client: self, rigId: rigId)
    }
}

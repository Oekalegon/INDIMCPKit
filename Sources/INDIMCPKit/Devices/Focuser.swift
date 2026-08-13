/// A rig-scoped handle for the `focuser`-role component of a saved rig.
///
/// Obtained via `INDIMCPClient.focuser(rigId:)`, not constructed directly. See `Mount`'s doc
/// comment for the connectivity-check behavior shared by every device-type handle.
public struct Focuser: Sendable {
    private let client: INDIMCPClient
    public let rigId: String

    init(client: INDIMCPClient, rigId: String) {
        self.client = client
        self.rigId = rigId
    }

    /// Connects the rig's focuser device. No connectivity check first — that's the point of this
    /// call.
    public func connect() async throws -> ScriptRunStarted {
        try await client.connectDevice(rigId: rigId, role: Role.focuser.rawValue)
    }

    /// Disconnects the rig's focuser device.
    public func disconnect() async throws -> ScriptRunStarted {
        try await client.disconnectDevice(rigId: rigId, role: Role.focuser.rawValue)
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

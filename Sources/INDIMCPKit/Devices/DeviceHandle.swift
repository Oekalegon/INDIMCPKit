/// Shared shape for a rig-scoped device-type handle (`Mount`, `Camera`, `FilterWheel`, `Focuser`).
///
/// `connect()`/`disconnect()` are identical across every conforming type — only the `role`
/// differs — so they're provided once here instead of copy-pasted per type.
protocol DeviceHandle: Sendable {
    var client: INDIMCPClient { get }
    var rigId: String { get }
    var role: Role { get }
}

extension DeviceHandle {
    /// Connects this rig's device for `role`. No connectivity check first — that's the point of
    /// this call.
    public func connect() async throws -> ScriptRunStarted {
        try await client.connectDevice(rigId: rigId, role: role.rawValue)
    }

    /// Disconnects this rig's device for `role`.
    public func disconnect() async throws -> ScriptRunStarted {
        try await client.disconnectDevice(rigId: rigId, role: role.rawValue)
    }
}

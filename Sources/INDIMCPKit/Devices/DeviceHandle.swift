/// Shared shape for a rig-scoped device-type handle (`Mount`, `Camera`, `FilterWheel`, `Focuser`).
///
/// `connect()`/`disconnect()` are identical across every conforming type — only the `role`
/// differs — so they're provided once here instead of copy-pasted per type.
///
/// Must be `public`, not `internal`: a `public` type conforming to an `internal` protocol can't
/// expose that protocol's default-implemented methods to callers outside this module, even if
/// the extension methods are themselves marked `public` — the requirement's effective access
/// level is capped by the protocol's own. `Mount`/`Camera`/`FilterWheel`/`Focuser`'s `connect()`/
/// `disconnect()` were silently uncallable from any consumer of this package until this was
/// caught by building `INDIMCPKitTestApp` (a real external module) against them — `swift test`
/// alone didn't catch it, since `@testable import` bypasses access control entirely.
public protocol DeviceHandle: Sendable {
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

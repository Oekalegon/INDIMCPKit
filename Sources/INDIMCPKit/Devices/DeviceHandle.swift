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
    /// The MCP client this device handle was obtained from.
    var client: INDIMCPClient { get }
    /// The id of the rig this device handle belongs to.
    var rigId: String { get }
    /// The role this device handle plays within its rig.
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

    /// Whether this rig currently has a connected component for `role` — see
    /// `INDIMCPClient.isDeviceConnected` for what this can and can't guarantee.
    public func isConnected() async throws -> Bool {
        try await client.isDeviceConnected(role: role, rigId: rigId)
    }

    /// Best-effort live property snapshot for this rig's `role` component — `nil` if the rig has
    /// no single component for `role` (missing or ambiguous), that component has no `device` name
    /// resolved, or the property read itself fails for any reason (transport/protocol error, INDI
    /// messaging not started, device never seen by the server, ...). Collapsing every failure
    /// reason into one `nil` is deliberate: this backs read-only, UI-oriented getters (`Camera`'s
    /// property getters, `FilterWheel`'s) that have nothing sensible to distinguish between "not
    /// connected," "not yet observed," and "transport error" for — callers that need to tell those
    /// apart should call `getDeviceProperties(device:)` themselves instead of relying on this.
    func liveProperties() async throws -> DeviceProperties? {
        let rig = try await client.getRig(id: rigId)
        guard let device = uniqueComponent(for: role, in: rig)?.device else {
            return nil
        }
        return try? await client.getDeviceProperties(device: device)
    }
}

/// The rig's single component declaring `role` — `nil` if it declares zero or more than one.
/// Shared by read-only, best-effort callers (`Camera`'s property getters, `FilterWheel`'s)
/// that have nothing sensible to read either way when a role is ambiguous — contrast
/// `resolveUniqueComponent(for:in:rigId:)`, which throws instead, for callers that need to
/// mutate or otherwise commit to exactly one component.
func uniqueComponent(for role: Role, in rig: Rig) -> Component? {
    let matches = rig.components.filter { $0.role == role }
    return matches.count == 1 ? matches.first : nil
}

/// The rig's single component declaring `role`, throwing a clear `DeviceControlError` if it
/// declares zero (`.noComponentForRole`) or more than one (`.ambiguousComponentForRole`) —
/// for callers that need to resolve or mutate exactly one component and can't just return a
/// soft `nil`/empty result the way `uniqueComponent(for:in:)`'s read-only callers can.
func resolveUniqueComponent(for role: Role, in rig: Rig, rigId: String) throws -> Component {
    let matches = rig.components.filter { $0.role == role }
    guard let component = matches.first, matches.count == 1 else {
        if matches.isEmpty {
            throw DeviceControlError.noComponentForRole(role: role, rigId: rigId)
        }
        throw DeviceControlError.ambiguousComponentForRole(role: role, rigId: rigId)
    }
    return component
}

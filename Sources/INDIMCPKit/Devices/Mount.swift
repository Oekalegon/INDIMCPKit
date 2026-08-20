/// A rig-scoped handle for the `mount`-role component of a saved rig.
///
/// Obtained via `INDIMCPClient.mount(rigId:)`, not constructed directly. Every command here
/// first runs a best-effort connectivity check (see `INDIMCPClient.ensureConnected`) before
/// issuing the underlying `INDIMCPClient` call — a friendlier, immediate `DeviceControlError`
/// instead of a script run that starts only to fail on its first step, though it's not a
/// guarantee (the device could still disconnect between the check and the command). That check
/// itself needs INDI messaging running server-side, so a call here can also throw
/// `INDIMCPClientError` (not just `DeviceControlError`) if `startINDIMessaging()` hasn't been
/// called yet — see `ensureConnected`'s doc comment.
public struct Mount: DeviceHandle {
    /// The MCP client this device handle was obtained from.
    public let client: INDIMCPClient
    /// The id of the rig this device handle belongs to.
    public let rigId: String
    /// The role this device handle plays within its rig.
    public let role: Role = .mount

    init(client: INDIMCPClient, rigId: String) {
        self.client = client
        self.rigId = rigId
    }

    /// Parks the mount.
    public func park() async throws -> ScriptRunStarted {
        try await client.ensureConnected(role: .mount, rigId: rigId)
        return try await client.park(rigId: rigId)
    }

    /// Unparks the mount.
    public func unpark() async throws -> ScriptRunStarted {
        try await client.ensureConnected(role: .mount, rigId: rigId)
        return try await client.unpark(rigId: rigId)
    }

    /// Slews to a fixed RA/Dec. `ra` is in hours, `dec` in degrees.
    public func slew(ra: Double, dec: Double) async throws -> ScriptRunStarted {
        try await client.ensureConnected(role: .mount, rigId: rigId)
        return try await client.slew(rigId: rigId, ra: ra, dec: dec)
    }

    /// Turns off mount tracking.
    public func trackOff() async throws -> ScriptRunStarted {
        try await client.ensureConnected(role: .mount, rigId: rigId)
        return try await client.trackOff(rigId: rigId)
    }

    /// Selects the mount's tracking mode. See `INDIMCPClient.setTrackMode` for
    /// `modeSwitchElement`'s accepted values.
    public func setTrackMode(_ modeSwitchElement: String) async throws -> ScriptRunStarted {
        try await client.ensureConnected(role: .mount, rigId: rigId)
        return try await client.setTrackMode(rigId: rigId, modeSwitchElement: modeSwitchElement)
    }

    /// Selects custom tracking and sets its RA/Dec rate.
    public func setCustomTrackingRate(
        raRateArcsecPerSec: Double,
        decRateArcsecPerSec: Double
    ) async throws -> ScriptRunStarted {
        try await client.ensureConnected(role: .mount, rigId: rigId)
        return try await client.setCustomTrackingRate(
            rigId: rigId,
            raRateArcsecPerSec: raRateArcsecPerSec,
            decRateArcsecPerSec: decRateArcsecPerSec
        )
    }
}

extension INDIMCPClient {
    /// A handle for rig `rigId`'s `mount`-role component.
    public func mount(rigId: String) -> Mount {
        Mount(client: self, rigId: rigId)
    }
}

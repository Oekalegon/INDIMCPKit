import MCP

/// Raw, unguarded tool calls — no park/connection-state checking happens client-side before any
/// of these issue a real mount command. `Mount` (the device abstraction) adds that; callers using
/// this file directly are responsible for their own state checks (e.g. via `checkRig`) before
/// issuing hardware commands here.
extension INDIMCPClient {
    /// `mount_action(rig_id, action, ...)`, shared by every method below — replaces the old
    /// dedicated `park`/`unpark`/`slew`/`track_off`/`set_track_mode`/`set_custom_tracking_rate`
    /// tools (INDIMCP-116).
    private func mountAction(rigId: String, action: String, extra: [String: Value] = [:]) async throws -> ScriptRunStarted {
        var arguments: [String: Value] = ["rig_id": .string(rigId), "action": .string(action)]
        arguments.merge(extra) { _, new in new }
        return try await callTool("mount_action", arguments: arguments, decoding: ScriptRunStarted.self)
    }

    /// Parks the rig's mount.
    ///
    /// Like every tool in this file, this starts a script run and returns immediately with a
    /// `runId` — poll `getScriptStatus(runId:)` for progress and the eventual outcome, or use
    /// `cancelScript` to stop it. It does not itself wait for the mount to finish parking.
    public func park(rigId: String) async throws -> ScriptRunStarted {
        try await mountAction(rigId: rigId, action: "park")
    }

    /// Unparks the rig's mount.
    public func unpark(rigId: String) async throws -> ScriptRunStarted {
        try await mountAction(rigId: rigId, action: "unpark")
    }

    /// Slews the rig's mount to a fixed RA/Dec. `ra` is in hours, `dec` in degrees.
    ///
    /// Slewing to a named object (e.g. `"M101"`) isn't supported by the server yet.
    public func slew(rigId: String, ra: Double, dec: Double) async throws -> ScriptRunStarted {
        try await mountAction(rigId: rigId, action: "slew", extra: ["ra": .double(ra), "dec": .double(dec)])
    }

    /// Turns off the rig's mount tracking.
    public func trackOff(rigId: String) async throws -> ScriptRunStarted {
        try await mountAction(rigId: rigId, action: "track_off")
    }

    /// Selects the rig's mount tracking mode.
    ///
    /// `modeSwitchElement` is the INDI `TELESCOPE_TRACK_MODE` switch member to enable, e.g.
    /// `"TRACK_SIDEREAL"`, `"TRACK_SOLAR"`, `"TRACK_LUNAR"`, or `"TRACK_CUSTOM"` (pair the last
    /// with `setCustomTrackingRate` to also set a custom rate).
    public func setTrackMode(rigId: String, modeSwitchElement: String) async throws -> ScriptRunStarted {
        try await mountAction(
            rigId: rigId,
            action: "set_track_mode",
            extra: ["modeSwitchElement": .string(modeSwitchElement)]
        )
    }

    /// Selects custom tracking on the rig's mount and sets its RA/Dec rate.
    public func setCustomTrackingRate(
        rigId: String,
        raRateArcsecPerSec: Double,
        decRateArcsecPerSec: Double
    ) async throws -> ScriptRunStarted {
        try await mountAction(
            rigId: rigId,
            action: "set_custom_tracking_rate",
            extra: [
                "raRateArcsecPerSec": .double(raRateArcsecPerSec),
                "decRateArcsecPerSec": .double(decRateArcsecPerSec),
            ]
        )
    }
}

import MCP

extension INDIMCPClient {
    /// Parks the rig's mount.
    ///
    /// Like every tool in this file, this starts a script run and returns immediately with a
    /// `runId` — poll `getScriptStatus(runId:)` for progress and the eventual outcome, or use
    /// `cancelScript` to stop it. It does not itself wait for the mount to finish parking.
    public func park(rigId: String) async throws -> ScriptRunStarted {
        try await callTool("park", arguments: ["rig_id": .string(rigId)], decoding: ScriptRunStarted.self)
    }

    /// Unparks the rig's mount.
    public func unpark(rigId: String) async throws -> ScriptRunStarted {
        try await callTool("unpark", arguments: ["rig_id": .string(rigId)], decoding: ScriptRunStarted.self)
    }

    /// Slews the rig's mount to a fixed RA/Dec. `ra` is in hours, `dec` in degrees.
    ///
    /// Slewing to a named object (e.g. `"M101"`) isn't supported by the server yet.
    public func slew(rigId: String, ra: Double, dec: Double) async throws -> ScriptRunStarted {
        try await callTool(
            "slew",
            arguments: ["rig_id": .string(rigId), "ra": .double(ra), "dec": .double(dec)],
            decoding: ScriptRunStarted.self
        )
    }

    /// Turns off the rig's mount tracking.
    public func trackOff(rigId: String) async throws -> ScriptRunStarted {
        try await callTool("track_off", arguments: ["rig_id": .string(rigId)], decoding: ScriptRunStarted.self)
    }

    /// Selects the rig's mount tracking mode.
    ///
    /// `modeSwitchElement` is the INDI `TELESCOPE_TRACK_MODE` switch member to enable, e.g.
    /// `"TRACK_SIDEREAL"`, `"TRACK_SOLAR"`, `"TRACK_LUNAR"`, or `"TRACK_CUSTOM"` (pair the last
    /// with `setCustomTrackingRate` to also set a custom rate).
    public func setTrackMode(rigId: String, modeSwitchElement: String) async throws -> ScriptRunStarted {
        try await callTool(
            "set_track_mode",
            arguments: ["rig_id": .string(rigId), "modeSwitchElement": .string(modeSwitchElement)],
            decoding: ScriptRunStarted.self
        )
    }

    /// Selects custom tracking on the rig's mount and sets its RA/Dec rate.
    public func setCustomTrackingRate(
        rigId: String,
        raRateArcsecPerSec: Double,
        decRateArcsecPerSec: Double
    ) async throws -> ScriptRunStarted {
        try await callTool(
            "set_custom_tracking_rate",
            arguments: [
                "rig_id": .string(rigId),
                "raRateArcsecPerSec": .double(raRateArcsecPerSec),
                "decRateArcsecPerSec": .double(decRateArcsecPerSec),
            ],
            decoding: ScriptRunStarted.self
        )
    }
}

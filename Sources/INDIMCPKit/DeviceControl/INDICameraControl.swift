import MCP

extension INDIMCPClient {
    /// `camera_action(rig_id, action, ...)`, shared by every method below — replaces the old
    /// dedicated `cool_camera`/`cooler_on`/`cooler_off`/`abort_exposure`/`capture_frame` tools
    /// (INDIMCP-116). Note the action is `"cool"`, not `"cool_camera"`.
    private func cameraAction(rigId: String, action: String, extra: [String: Value] = [:]) async throws -> ScriptRunStarted {
        var arguments: [String: Value] = ["rig_id": .string(rigId), "action": .string(action)]
        arguments.merge(extra) { _, new in new }
        return try await callTool("camera_action", arguments: arguments, decoding: ScriptRunStarted.self)
    }

    /// Cools the rig's camera to `targetTempC` and waits for it to stabilize.
    public func coolCamera(
        rigId: String,
        targetTempC: Double = -10,
        timeoutSeconds: Double = 300
    ) async throws -> ScriptRunStarted {
        try await cameraAction(
            rigId: rigId,
            action: "cool",
            extra: ["targetTempC": .double(targetTempC), "timeoutSeconds": .double(timeoutSeconds)]
        )
    }

    /// Turns on the rig's camera cooler.
    public func coolerOn(rigId: String) async throws -> ScriptRunStarted {
        try await cameraAction(rigId: rigId, action: "cooler_on")
    }

    /// Turns off the rig's camera cooler.
    public func coolerOff(rigId: String) async throws -> ScriptRunStarted {
        try await cameraAction(rigId: rigId, action: "cooler_off")
    }

    /// Aborts the rig's camera's currently in-progress exposure, if any.
    ///
    /// New capability (INDIMCP-116) — there was no server-side tool for this at all before
    /// `camera_action` gained it as a new action.
    public func abortExposure(rigId: String) async throws -> ScriptRunStarted {
        try await cameraAction(rigId: rigId, action: "abort_exposure")
    }

    /// Captures a single frame from the rig's camera.
    ///
    /// `gain`/`offset` omitted (the default) leave the device's current setting alone rather
    /// than sending a fixed number. `frameX`/`frameY`/`frameWidth`/`frameHeight` default to the
    /// full sensor; set all four together for a sub-frame. `locationId`, if given, identifies a
    /// saved `Observatory` used for this frame's celestial-context FITS headers, best-effort.
    public func captureFrame(
        rigId: String,
        exposureSeconds: Double,
        frameType: FrameType = .light,
        binningX: Int = 1,
        binningY: Int = 1,
        gain: Double? = nil,
        offset: Double? = nil,
        frameX: Int? = nil,
        frameY: Int? = nil,
        frameWidth: Int? = nil,
        frameHeight: Int? = nil,
        locationId: String? = nil
    ) async throws -> ScriptRunStarted {
        var extra: [String: Value] = [
            "exposureSeconds": .double(exposureSeconds),
            "frameType": .string(frameType.rawValue),
            "binningX": .int(binningX),
            "binningY": .int(binningY),
        ]
        if let gain {
            extra["gain"] = .double(gain)
        }
        if let offset {
            extra["offset"] = .double(offset)
        }
        if let frameX {
            extra["frameX"] = .int(frameX)
        }
        if let frameY {
            extra["frameY"] = .int(frameY)
        }
        if let frameWidth {
            extra["frameWidth"] = .int(frameWidth)
        }
        if let frameHeight {
            extra["frameHeight"] = .int(frameHeight)
        }
        if let locationId {
            extra["location_id"] = .string(locationId)
        }
        return try await cameraAction(rigId: rigId, action: "capture_frame", extra: extra)
    }
}

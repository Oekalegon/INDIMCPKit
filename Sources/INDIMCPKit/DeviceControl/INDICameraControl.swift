import MCP

extension INDIMCPClient {
    /// Cools the rig's camera to `targetTempC` and waits for it to stabilize.
    public func coolCamera(
        rigId: String,
        targetTempC: Double = -10,
        timeoutSeconds: Double = 300
    ) async throws -> ScriptRunStarted {
        try await callTool(
            "cool_camera",
            arguments: [
                "rig_id": .string(rigId),
                "targetTempC": .double(targetTempC),
                "timeoutSeconds": .double(timeoutSeconds),
            ],
            decoding: ScriptRunStarted.self
        )
    }

    /// Turns on the rig's camera cooler.
    public func coolerOn(rigId: String) async throws -> ScriptRunStarted {
        try await callTool("cooler_on", arguments: ["rig_id": .string(rigId)], decoding: ScriptRunStarted.self)
    }

    /// Turns off the rig's camera cooler.
    public func coolerOff(rigId: String) async throws -> ScriptRunStarted {
        try await callTool("cooler_off", arguments: ["rig_id": .string(rigId)], decoding: ScriptRunStarted.self)
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
        var arguments: [String: Value] = [
            "rig_id": .string(rigId),
            "exposureSeconds": .double(exposureSeconds),
            "frameType": .string(frameType.rawValue),
            "binningX": .int(binningX),
            "binningY": .int(binningY),
        ]
        if let gain {
            arguments["gain"] = .double(gain)
        }
        if let offset {
            arguments["offset"] = .double(offset)
        }
        if let frameX {
            arguments["frameX"] = .int(frameX)
        }
        if let frameY {
            arguments["frameY"] = .int(frameY)
        }
        if let frameWidth {
            arguments["frameWidth"] = .int(frameWidth)
        }
        if let frameHeight {
            arguments["frameHeight"] = .int(frameHeight)
        }
        if let locationId {
            arguments["location_id"] = .string(locationId)
        }
        return try await callTool("capture_frame", arguments: arguments, decoding: ScriptRunStarted.self)
    }
}

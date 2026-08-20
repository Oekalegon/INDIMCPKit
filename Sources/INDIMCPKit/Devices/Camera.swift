/// A rig-scoped handle for the `camera`-role component of a saved rig.
///
/// Obtained via `INDIMCPClient.camera(rigId:)`, not constructed directly. See `Mount`'s doc
/// comment for the connectivity-check behavior shared by every device-type handle.
public struct Camera: DeviceHandle {
    /// The MCP client this device handle was obtained from.
    public let client: INDIMCPClient
    /// The id of the rig this device handle belongs to.
    public let rigId: String
    /// The role this device handle plays within its rig.
    public let role: Role = .camera

    init(client: INDIMCPClient, rigId: String) {
        self.client = client
        self.rigId = rigId
    }

    /// Cools the camera to `targetTempC` and waits for it to stabilize.
    public func coolCamera(targetTempC: Double = -10, timeoutSeconds: Double = 300) async throws -> ScriptRunStarted {
        try await client.ensureConnected(role: .camera, rigId: rigId)
        return try await client.coolCamera(rigId: rigId, targetTempC: targetTempC, timeoutSeconds: timeoutSeconds)
    }

    /// Turns on the camera cooler.
    public func coolerOn() async throws -> ScriptRunStarted {
        try await client.ensureConnected(role: .camera, rigId: rigId)
        return try await client.coolerOn(rigId: rigId)
    }

    /// Turns off the camera cooler.
    public func coolerOff() async throws -> ScriptRunStarted {
        try await client.ensureConnected(role: .camera, rigId: rigId)
        return try await client.coolerOff(rigId: rigId)
    }

    /// Whether the cooler is currently on, going by the most recently observed `CCD_COOLER`
    /// event on this rig's camera device — `nil` if that can't be determined (no `CCD_COOLER`
    /// event seen yet, e.g. before INDI messaging has streamed one, or this rig's camera
    /// component has no `device` name resolved).
    ///
    /// UI-oriented, not authoritative: this is only ever as fresh as the last streamed event
    /// (`listINDIMessages` isn't a live subscription, just the most recent snapshot), the same
    /// caveat `INDIMCPClient.isDeviceConnected` carries.
    public func isCoolerOn() async throws -> Bool? {
        let rig = try await client.getRig(id: rigId)
        guard let device = rig.components.first(where: { $0.role == .camera })?.device else {
            return nil
        }
        // Widening limits, not a single fixed one: CCD_COOLER only fires when the switch
        // changes, but CCD_TEMPERATURE (and anything else on this device) can update far more
        // often — most visibly during coolCamera's own wait_for step, exactly when a caller is
        // most likely to be asking this. A too-small window would let those crowd CCD_COOLER out
        // and report "unknown" for a state that's actually still perfectly well known.
        for limit in [20, 100, 500] {
            let events = try await client.listINDIMessages(device: device, limit: limit)
            if let latest = events.first(where: { $0.name == "CCD_COOLER" }) {
                return latest.elements?["COOLER_ON"] == "On"
            }
        }
        return nil
    }

    /// Captures a single frame. See `INDIMCPClient.captureFrame` for the full parameter set.
    public func captureFrame(
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
        try await client.ensureConnected(role: .camera, rigId: rigId)
        return try await client.captureFrame(
            rigId: rigId,
            exposureSeconds: exposureSeconds,
            frameType: frameType,
            binningX: binningX,
            binningY: binningY,
            gain: gain,
            offset: offset,
            frameX: frameX,
            frameY: frameY,
            frameWidth: frameWidth,
            frameHeight: frameHeight,
            locationId: locationId
        )
    }

    /// Cools the camera to `targetTempC`, then captures `count` dark frames. See
    /// `INDIMCPClient.captureDarkSequence` for the full parameter set.
    public func captureDarkSequence(
        exposureSeconds: Double,
        count: Int,
        targetTempC: Double = -10,
        gain: Double? = nil,
        offset: Double? = nil,
        locationId: String? = nil
    ) async throws -> ScriptRunStarted {
        try await client.ensureConnected(role: .camera, rigId: rigId)
        return try await client.captureDarkSequence(
            rigId: rigId,
            exposureSeconds: exposureSeconds,
            count: count,
            targetTempC: targetTempC,
            gain: gain,
            offset: offset,
            locationId: locationId
        )
    }

    /// Captures `count` bias frames back to back. See `INDIMCPClient.captureBiasSequence` for
    /// the full parameter set.
    public func captureBiasSequence(
        count: Int,
        exposureSeconds: Double = 0,
        gain: Double? = nil,
        offset: Double? = nil,
        locationId: String? = nil
    ) async throws -> ScriptRunStarted {
        try await client.ensureConnected(role: .camera, rigId: rigId)
        return try await client.captureBiasSequence(
            rigId: rigId,
            count: count,
            exposureSeconds: exposureSeconds,
            gain: gain,
            offset: offset,
            locationId: locationId
        )
    }

    /// Selects `filterName`, moves the focuser to `focusPosition`, then captures `count` flat
    /// frames. See `INDIMCPClient.captureFlatSequence` for the full parameter set.
    public func captureFlatSequence(
        filterName: String,
        focusPosition: Int,
        exposureSeconds: Double,
        count: Int,
        gain: Double? = nil,
        offset: Double? = nil,
        locationId: String? = nil
    ) async throws -> ScriptRunStarted {
        try await client.ensureConnected(role: .camera, rigId: rigId)
        return try await client.captureFlatSequence(
            rigId: rigId,
            filterName: filterName,
            focusPosition: focusPosition,
            exposureSeconds: exposureSeconds,
            count: count,
            gain: gain,
            offset: offset,
            locationId: locationId
        )
    }

    /// Slews to `ra`/`dec`, selects `filterName`, moves the focuser to `focusPosition`, cools
    /// the camera to `targetTempC`, then captures `count` light frames. See
    /// `INDIMCPClient.captureLightSequence` for the full parameter set.
    public func captureLightSequence(
        ra: Double,
        dec: Double,
        filterName: String,
        focusPosition: Int,
        exposureSeconds: Double,
        count: Int,
        objectName: String? = nil,
        targetTempC: Double = -10,
        gain: Double? = nil,
        offset: Double? = nil,
        locationId: String? = nil
    ) async throws -> ScriptRunStarted {
        try await client.ensureConnected(role: .camera, rigId: rigId)
        return try await client.captureLightSequence(
            rigId: rigId,
            ra: ra,
            dec: dec,
            filterName: filterName,
            focusPosition: focusPosition,
            exposureSeconds: exposureSeconds,
            count: count,
            objectName: objectName,
            targetTempC: targetTempC,
            gain: gain,
            offset: offset,
            locationId: locationId
        )
    }
}

extension INDIMCPClient {
    /// A handle for rig `rigId`'s `camera`-role component.
    public func camera(rigId: String) -> Camera {
        Camera(client: self, rigId: rigId)
    }
}

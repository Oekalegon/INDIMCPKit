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

    /// Aborts the camera's currently in-progress exposure, if any. See
    /// `INDIMCPClient.abortExposure(rigId:)` for the no-exposure-running caveat.
    public func abortExposure() async throws -> ScriptRunStarted {
        try await client.ensureConnected(role: .camera, rigId: rigId)
        return try await client.abortExposure(rigId: rigId)
    }

    /// Whether the cooler is currently on, read directly from this rig's camera device's live
    /// `CCD_COOLER` property — `nil` if that can't be determined (this rig's camera component has
    /// no `device` name resolved, the device has never reported `CCD_COOLER` at all, or the
    /// server has never seen the device — e.g. before INDI messaging has connected to it).
    ///
    /// `nil` here specifically means "can't currently tell," not "confirmed off" — it also covers
    /// any other failure from the underlying `getDeviceProperties` call (a transport/protocol
    /// error, INDI messaging not having been started, etc.), which this swallows rather than
    /// throws, matching this method's existing UI-oriented, best-effort contract. Callers that
    /// need to distinguish "not yet known" from "something's actually broken" should call
    /// `getDeviceProperties(device:)` themselves instead of relying on this.
    ///
    /// UI-oriented, not authoritative: reflects whatever `getDeviceProperties` currently reports,
    /// same caveat `INDIMCPClient.isDeviceConnected` carries. Was previously derived from the most
    /// recently observed `CCD_COOLER` event via `listINDIMessages`, which INDIMCP-114 removed with
    /// no replacement tool — this reads the live property directly instead (IMCPKIT-28).
    public func isCoolerOn() async throws -> Bool? {
        let rig = try await client.getRig(id: rigId)
        guard let device = rig.components.first(where: { $0.role == .camera })?.device else {
            return nil
        }
        guard let properties = try? await client.getDeviceProperties(device: device) else {
            return nil
        }
        return properties.properties["CCD_COOLER"]?.elements["COOLER_ON"] == "On"
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
    ///
    /// Only the camera's connectivity is pre-checked here — a disconnected filter wheel or
    /// focuser will still only surface as a script-run failure, not an upfront
    /// `DeviceControlError`.
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
    ///
    /// Only the camera's connectivity is pre-checked here — a disconnected mount, filter wheel,
    /// or focuser will still only surface as a script-run failure, not an upfront
    /// `DeviceControlError`.
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

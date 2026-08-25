/// `Camera`-scoped wrappers over the composed capture-sequence scripts.
///
/// Split from `Camera.swift` (which was crossing 500 lines) once this PR's changes added
/// binning/ROI parameters to all four methods below — mirrors the split already established on
/// the `INDIMCPClient` side, where these same four scripts live in their own
/// `DeviceControl/INDICaptureSequences.swift` rather than `INDICameraControl.swift`.
extension Camera {
    /// Cools the camera to `targetTempC`, then captures `count` dark frames. See
    /// `INDIMCPClient.captureDarkSequence` for the full parameter set.
    public func captureDarkSequence(
        exposureSeconds: Double,
        count: Int,
        targetTempC: Double = -10,
        gain: Double? = nil,
        offset: Double? = nil,
        binningX: Int = 1,
        binningY: Int = 1,
        frameX: Int? = nil,
        frameY: Int? = nil,
        frameWidth: Int? = nil,
        frameHeight: Int? = nil,
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
            binningX: binningX,
            binningY: binningY,
            frameX: frameX,
            frameY: frameY,
            frameWidth: frameWidth,
            frameHeight: frameHeight,
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
        binningX: Int = 1,
        binningY: Int = 1,
        frameX: Int? = nil,
        frameY: Int? = nil,
        frameWidth: Int? = nil,
        frameHeight: Int? = nil,
        locationId: String? = nil
    ) async throws -> ScriptRunStarted {
        try await client.ensureConnected(role: .camera, rigId: rigId)
        return try await client.captureBiasSequence(
            rigId: rigId,
            count: count,
            exposureSeconds: exposureSeconds,
            gain: gain,
            offset: offset,
            binningX: binningX,
            binningY: binningY,
            frameX: frameX,
            frameY: frameY,
            frameWidth: frameWidth,
            frameHeight: frameHeight,
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
        binningX: Int = 1,
        binningY: Int = 1,
        frameX: Int? = nil,
        frameY: Int? = nil,
        frameWidth: Int? = nil,
        frameHeight: Int? = nil,
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
            binningX: binningX,
            binningY: binningY,
            frameX: frameX,
            frameY: frameY,
            frameWidth: frameWidth,
            frameHeight: frameHeight,
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
        binningX: Int = 1,
        binningY: Int = 1,
        frameX: Int? = nil,
        frameY: Int? = nil,
        frameWidth: Int? = nil,
        frameHeight: Int? = nil,
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
            binningX: binningX,
            binningY: binningY,
            frameX: frameX,
            frameY: frameY,
            frameWidth: frameWidth,
            frameHeight: frameHeight,
            locationId: locationId
        )
    }
}

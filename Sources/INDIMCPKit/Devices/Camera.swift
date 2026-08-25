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
        guard let properties = try await liveProperties() else {
            return nil
        }
        return Camera.coolerOn(from: properties)
    }

    // MARK: Cooler temperature/power

    /// Current sensor temperature, in Celsius — `nil` if that can't be determined (same reasons
    /// as `isCoolerOn`).
    public func currentTempC() async throws -> Double? {
        guard let properties = try await liveProperties() else {
            return nil
        }
        return Camera.doubleElement("CCD_TEMPERATURE", "CCD_TEMPERATURE_VALUE", from: properties)
    }

    /// The temperature the cooler is currently driving toward. Caveat: INDI's `CCD_TEMPERATURE`
    /// carries only one value — the driver doesn't separately report "requested" vs. "actual",
    /// so between a `setTargetTempC`/`coolCamera` call and the sensor settling, this reads the
    /// same live, still-changing value as `currentTempC()`. Kept as a distinct method (rather
    /// than documented as an alias) so call sites read as intent, and so this can be corrected
    /// transparently if a driver-specific target readback ever becomes available.
    public func targetTempC() async throws -> Double? {
        try await currentTempC()
    }

    /// Sets the cooler's target temperature without waiting for it to stabilize — unlike
    /// `coolCamera`, which blocks until settled. Returns once the driver acknowledges the new
    /// setpoint.
    public func setTargetTempC(_ targetTempC: Double) async throws {
        let device = try await connectedDeviceName()
        _ = try await client.sendINDIProperty(
            device: device,
            name: "CCD_TEMPERATURE",
            elements: ["CCD_TEMPERATURE_VALUE": String(targetTempC)]
        )
    }

    /// Cooler power, 0–100 (percent) — `nil` if this driver doesn't report `CCD_COOLER_POWER`
    /// (driver-dependent — not every camera driver exposes it), or for the same reasons
    /// `isCoolerOn`'s `nil` case applies.
    ///
    /// - Note: `CCD_COOLER_POWER`'s element name (`CCD_COOLER_VALUE`) is asserted from INDI's
    ///   standard property list, not confirmed against a real driver's property dump — verify
    ///   against one before relying on this in a safety-relevant path.
    public func coolerPowerPercent() async throws -> Double? {
        guard let properties = try await liveProperties() else {
            return nil
        }
        return Camera.doubleElement("CCD_COOLER_POWER", "CCD_COOLER_VALUE", from: properties)
    }

    // MARK: Exposure

    /// Seconds remaining on the exposure currently in progress — `nil` if that can't be
    /// determined (same reasons as `isCoolerOn`'s `nil` case).
    ///
    /// - Note: Expected to read `0` once an exposure finishes, matching how most INDI camera
    ///   drivers report `CCD_EXPOSURE_VALUE`, but this isn't guaranteed by INDI's protocol and
    ///   varies by driver — treat a `0` as "not counting down," not necessarily "definitely idle."
    public func exposureCountdownSeconds() async throws -> Double? {
        guard let properties = try await liveProperties() else {
            return nil
        }
        return Camera.doubleElement("CCD_EXPOSURE", "CCD_EXPOSURE_VALUE", from: properties)
    }

    // MARK: Sensor settings (standing state, independent of any one captureFrame call)

    /// Current sensor gain — `nil` if that can't be determined (same reasons as `isCoolerOn`'s
    /// `nil` case), or if this driver doesn't expose `CCD_GAIN` as a standing setting at all
    /// (some drivers only accept gain per-exposure, via `captureFrame(gain:)`).
    public func gain() async throws -> Double? {
        guard let properties = try await liveProperties() else {
            return nil
        }
        return Camera.doubleElement("CCD_GAIN", "GAIN", from: properties)
    }

    /// Sets the sensor gain as standing state, independent of any one `captureFrame` call.
    public func setGain(_ gain: Double) async throws {
        let device = try await connectedDeviceName()
        _ = try await client.sendINDIProperty(device: device, name: "CCD_GAIN", elements: ["GAIN": String(gain)])
    }

    /// Current sensor offset — `nil` for the same reasons as `gain()`'s `nil` case.
    public func offset() async throws -> Double? {
        guard let properties = try await liveProperties() else {
            return nil
        }
        return Camera.doubleElement("CCD_OFFSET", "OFFSET", from: properties)
    }

    /// Sets the sensor offset as standing state, independent of any one `captureFrame` call.
    public func setOffset(_ offset: Double) async throws {
        let device = try await connectedDeviceName()
        _ = try await client.sendINDIProperty(device: device, name: "CCD_OFFSET", elements: ["OFFSET": String(offset)])
    }

    /// Current pixel binning — `nil` if that can't be determined (same reasons as `isCoolerOn`'s
    /// `nil` case).
    public func binning() async throws -> (x: Int, y: Int)? {
        guard let properties = try await liveProperties() else {
            return nil
        }
        return Camera.binning(from: properties)
    }

    /// Sets pixel binning as standing state, independent of any one `captureFrame` call.
    public func setBinning(x: Int, y: Int) async throws {
        let device = try await connectedDeviceName()
        _ = try await client.sendINDIProperty(
            device: device,
            name: "CCD_BINNING",
            elements: ["HOR_BIN": String(x), "VER_BIN": String(y)]
        )
    }

    /// Current sub-frame ROI (`x`/`y` top-left corner, `width`/`height`, all in pixels) — `nil`
    /// if that can't be determined (same reasons as `isCoolerOn`'s `nil` case).
    ///
    /// - Note: `CCD_FRAME`'s element names (`X`/`Y`/`WIDTH`/`HEIGHT`) are asserted from INDI's
    ///   standard property list, not confirmed against a real driver's property dump — verify
    ///   against one before relying on this in a safety-relevant path.
    public func frame() async throws -> (x: Int, y: Int, width: Int, height: Int)? {
        guard let properties = try await liveProperties() else {
            return nil
        }
        return Camera.frame(from: properties)
    }

    /// Sets the sub-frame ROI as standing state, independent of any one `captureFrame` call. Set
    /// all four together for a sub-frame, or to the sensor's full dimensions to reset it.
    public func setFrame(x: Int, y: Int, width: Int, height: Int) async throws {
        let device = try await connectedDeviceName()
        _ = try await client.sendINDIProperty(
            device: device,
            name: "CCD_FRAME",
            elements: ["X": String(x), "Y": String(y), "WIDTH": String(width), "HEIGHT": String(height)]
        )
    }

    /// The sensor's analog-to-digital bit depth, from static `CCD_INFO` — read-only. No `set`:
    /// only some CMOS drivers support switching capture format at all (`CCD_CAPTURE_FORMAT`), and
    /// INDIMCP-server doesn't currently wrap it. Revisit if a concrete camera needs it.
    public func bitDepth() async throws -> Int? {
        guard let properties = try await liveProperties() else {
            return nil
        }
        return Camera.intElement("CCD_INFO", "CCD_BITSPERPIXEL", from: properties)
    }

    /// Parses whether the cooler is on from an already-fetched `CCD_COOLER` snapshot — `nil` if
    /// that property hasn't been observed at all. Pure and offline-testable by design: this is
    /// the exact logic that once had a bug (`... == "On"` silently returning `false` instead of
    /// `nil` when `CCD_COOLER` was absent, via Swift's optional-chaining-then-compare collapsing
    /// to a concrete `Bool`) which only live verification happened to catch, since nothing here
    /// could be tested without a real server before this was split out. See `isCoolerOn()`.
    static func coolerOn(from properties: DeviceProperties) -> Bool? {
        guard let value = properties.properties["CCD_COOLER"]?.elements["COOLER_ON"] else {
            return nil
        }
        return value == "On"
    }

    /// Parses a `Double`-valued element from an already-fetched property snapshot — `nil` if
    /// `propertyName`/`elementName` isn't present. Pure and offline-testable; shared by every
    /// `Double`-returning getter above.
    static func doubleElement(_ propertyName: String, _ elementName: String, from properties: DeviceProperties) -> Double? {
        guard let value = properties.properties[propertyName]?.elements[elementName] else {
            return nil
        }
        return Double(value)
    }

    /// Parses an `Int`-valued element from an already-fetched property snapshot, tolerating
    /// INDI's float-on-the-wire number formatting (see `parseINDIInt`) — `nil` if
    /// `propertyName`/`elementName` isn't present or isn't parseable. Pure and offline-testable;
    /// shared by `bitDepth()` and (indirectly, via their own dedicated parsers) `binning()`/
    /// `frame()`.
    static func intElement(_ propertyName: String, _ elementName: String, from properties: DeviceProperties) -> Int? {
        parseINDIInt(properties.properties[propertyName]?.elements[elementName])
    }

    /// Parses `CCD_BINNING`'s `HOR_BIN`/`VER_BIN` elements from an already-fetched property
    /// snapshot — `nil` unless both are present and parseable. Pure and offline-testable.
    static func binning(from properties: DeviceProperties) -> (x: Int, y: Int)? {
        guard let elements = properties.properties["CCD_BINNING"]?.elements,
            let x = parseINDIInt(elements["HOR_BIN"]),
            let y = parseINDIInt(elements["VER_BIN"])
        else {
            return nil
        }
        return (x: x, y: y)
    }

    /// Parses `CCD_FRAME`'s `X`/`Y`/`WIDTH`/`HEIGHT` elements from an already-fetched property
    /// snapshot — `nil` unless all four are present and parseable. Pure and offline-testable.
    static func frame(from properties: DeviceProperties) -> (x: Int, y: Int, width: Int, height: Int)? {
        guard let elements = properties.properties["CCD_FRAME"]?.elements,
            let x = parseINDIInt(elements["X"]),
            let y = parseINDIInt(elements["Y"]),
            let width = parseINDIInt(elements["WIDTH"]),
            let height = parseINDIInt(elements["HEIGHT"])
        else {
            return nil
        }
        return (x: x, y: y, width: width, height: height)
    }

    /// Best-effort live property snapshot for this rig's camera device — `nil` if this rig's
    /// camera component has no `device` name resolved, or the property read itself fails for any
    /// reason (transport/protocol error, INDI messaging not started, device never seen by the
    /// server, ...). Shared by every property getter above; see `isCoolerOn`'s doc comment for
    /// why collapsing every failure reason into one `nil` is this method's deliberate contract,
    /// not an oversight.
    private func liveProperties() async throws -> DeviceProperties? {
        let rig = try await client.getRig(id: rigId)
        guard let device = rig.components.first(where: { $0.role == .camera })?.device else {
            return nil
        }
        return try? await client.getDeviceProperties(device: device)
    }

    /// Ensures this rig's camera is connected, then resolves its INDI device name — every setter
    /// above needs both before sending a raw property write, unlike the getters above (which
    /// tolerate an unresolved/disconnected device as part of their best-effort `nil` contract).
    private func connectedDeviceName() async throws -> String {
        try await client.ensureConnected(role: .camera, rigId: rigId)
        let rig = try await client.getRig(id: rigId)
        guard let device = rig.components.first(where: { $0.role == .camera })?.device else {
            throw DeviceControlError.noComponentForRole(role: .camera, rigId: rigId)
        }
        return device
    }

    /// Runs a bias + flat-dark sensor-analysis sweep across every `(gain, offset,
    /// flatExposureSeconds)` combination. See `INDIMCPClient.runSensorCalibrationSweep` for the
    /// full parameter set and combination-ordering rules.
    public func runSensorCalibrationSweep(
        gains: [Double],
        offsets: [Double],
        flatExposureSecondsList: [Double],
        biasCount: Int,
        darkCount: Int,
        biasExposureSeconds: Double = 0,
        locationId: String? = nil
    ) async throws -> SensorCalibrationSweepStarted {
        try await client.ensureConnected(role: .camera, rigId: rigId)
        return try await client.runSensorCalibrationSweep(
            rigId: rigId,
            gains: gains,
            offsets: offsets,
            flatExposureSecondsList: flatExposureSecondsList,
            biasCount: biasCount,
            darkCount: darkCount,
            biasExposureSeconds: biasExposureSeconds,
            locationId: locationId
        )
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

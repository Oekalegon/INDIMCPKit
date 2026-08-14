import MCP

/// Typed wrappers for the built-in composed capture-sequence scripts.
///
/// Unlike every other file in `DeviceControl`, these five scripts (`capture_dark_sequence`,
/// `capture_bias_sequence`, `capture_flat_sequence`, `capture_light_sequence`,
/// `capture_sensor_calibration_set`) have no dedicated server-side `@mcp.tool()` of their own —
/// confirmed against `INDIMCP-server`'s `server.py`, which only auto-generates a typed tool for
/// single-action scripts (`park`, `slew`, `capture_frame`, ...). These composed sequences are
/// reachable only through the generic `run_script` mechanism server-side, so these wrappers call
/// `runScript(scriptId:rigId:parameters:locationId:)` directly rather than a same-named tool,
/// unlike `park`/`slew`/etc.
extension INDIMCPClient {
    /// Cools the rig's camera to `targetTempC`, then captures `count` dark frames.
    ///
    /// Deliberately skips mount positioning, filter selection, and focus — only sensor
    /// temperature and `exposureSeconds` need to match the light frames this calibrates.
    public func captureDarkSequence(
        rigId: String,
        exposureSeconds: Double,
        count: Int,
        targetTempC: Double = -10,
        locationId: String? = nil
    ) async throws -> ScriptRunStarted {
        try await runScript(
            scriptId: "capture_dark_sequence",
            rigId: rigId,
            parameters: [
                "targetTempC": .double(targetTempC),
                "exposureSeconds": .double(exposureSeconds),
                "count": .int(count),
            ],
            locationId: locationId
        )
    }

    /// Captures `count` bias frames back to back.
    ///
    /// Needs none of mount position, filter, focus, or a specific sensor temperature — a bias
    /// frame is the shortest exposure the camera supports, shutter closed.
    public func captureBiasSequence(
        rigId: String,
        count: Int,
        exposureSeconds: Double = 0,
        locationId: String? = nil
    ) async throws -> ScriptRunStarted {
        try await runScript(
            scriptId: "capture_bias_sequence",
            rigId: rigId,
            parameters: [
                "exposureSeconds": .double(exposureSeconds),
                "count": .int(count),
            ],
            locationId: locationId
        )
    }

    /// Selects `filterName`, moves the focuser to `focusPosition`, then captures `count` flat
    /// frames.
    public func captureFlatSequence(
        rigId: String,
        filterName: String,
        focusPosition: Int,
        exposureSeconds: Double,
        count: Int,
        locationId: String? = nil
    ) async throws -> ScriptRunStarted {
        try await runScript(
            scriptId: "capture_flat_sequence",
            rigId: rigId,
            parameters: [
                "filterName": .string(filterName),
                "focusPosition": .int(focusPosition),
                "exposureSeconds": .double(exposureSeconds),
                "count": .int(count),
            ],
            locationId: locationId
        )
    }

    /// Slews to `ra`/`dec`, selects `filterName`, moves the focuser to `focusPosition`, cools
    /// the camera to `targetTempC`, then captures `count` light frames.
    ///
    /// `objectName`, if given, is written verbatim to each frame's FITS `OBJECT` keyword.
    public func captureLightSequence(
        rigId: String,
        ra: Double,
        dec: Double,
        filterName: String,
        focusPosition: Int,
        exposureSeconds: Double,
        count: Int,
        objectName: String? = nil,
        targetTempC: Double = -10,
        locationId: String? = nil
    ) async throws -> ScriptRunStarted {
        var parameters: [String: Value] = [
            "ra": .double(ra),
            "dec": .double(dec),
            "filterName": .string(filterName),
            "focusPosition": .int(focusPosition),
            "targetTempC": .double(targetTempC),
            "exposureSeconds": .double(exposureSeconds),
            "count": .int(count),
        ]
        if let objectName {
            parameters["objectName"] = .string(objectName)
        }
        return try await runScript(
            scriptId: "capture_light_sequence",
            rigId: rigId,
            parameters: parameters,
            locationId: locationId
        )
    }

    /// Captures a bias/flat/flat-dark calibration set at a single gain/offset setting
    /// (`capture_sensor_calibration_set`, INDIMCP-81) — `biasCount` bias frames, `flatCount` flat
    /// frames, and `darkCount` flat-dark frames (a dark frame at `flatExposureSeconds`, matching
    /// the flats), all at the given `gain`/`offset`.
    ///
    /// The per-setting building block for a sensor gain/offset sweep: this script has no
    /// list-valued parameter or loop construct to sweep a range itself, so sweeping multiple
    /// settings means calling this once per setting. Deliberately skips mount positioning, filter
    /// selection, and focus, like `captureBiasSequence`/`captureDarkSequence` — a calibration
    /// frame's illumination/focus source is whatever the rig is already pointed at.
    public func captureSensorCalibrationSet(
        rigId: String,
        flatExposureSeconds: Double,
        biasCount: Int,
        flatCount: Int,
        darkCount: Int,
        gain: Double? = nil,
        offset: Double? = nil,
        biasExposureSeconds: Double = 0.0,
        locationId: String? = nil
    ) async throws -> ScriptRunStarted {
        var parameters: [String: Value] = [
            "flatExposureSeconds": .double(flatExposureSeconds),
            "biasCount": .int(biasCount),
            "flatCount": .int(flatCount),
            "darkCount": .int(darkCount),
            "biasExposureSeconds": .double(biasExposureSeconds),
        ]
        if let gain {
            parameters["gain"] = .double(gain)
        }
        if let offset {
            parameters["offset"] = .double(offset)
        }
        return try await runScript(
            scriptId: "capture_sensor_calibration_set",
            rigId: rigId,
            parameters: parameters,
            locationId: locationId
        )
    }
}

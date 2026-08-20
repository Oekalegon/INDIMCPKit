import MCP

/// Typed wrappers for the built-in composed capture-sequence scripts.
///
/// Unlike every other file in `DeviceControl`, these four scripts (`capture_dark_sequence`,
/// `capture_bias_sequence`, `capture_flat_sequence`, `capture_light_sequence`) have no dedicated
/// server-side `@mcp.tool()` of their own — confirmed against `INDIMCP-server`'s `server.py`,
/// which only auto-generates a typed tool for single-action scripts (`park`, `slew`,
/// `capture_frame`, ...). These composed sequences are reachable only through the generic
/// `run_script` mechanism server-side, so these wrappers call `runScript(scriptId:rigId:
/// parameters:locationId:)` directly rather than a same-named tool, unlike `park`/`slew`/etc.
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
    ///
    /// `gain`/`offset` omitted (the default) leave the device's current setting alone rather
    /// than sending a fixed number.
    ///
    /// - Parameters:
    ///   - rigId: The `Rig` to run the sequence on, as saved via `saveRig`.
    ///   - filterName: Name of the filter to select before capturing, matching one of the rig's
    ///     configured filter-wheel slots.
    ///   - focusPosition: Absolute focuser position to move to before capturing, in the
    ///     focuser's native step units.
    ///   - exposureSeconds: Exposure length for each flat frame, in seconds.
    ///   - count: Number of flat frames to capture.
    ///   - gain: Camera gain to apply to each frame, in the device's native units. Omit to leave
    ///     the camera's current gain setting unchanged.
    ///   - offset: Camera offset to apply to each frame, in the device's native units. Omit to
    ///     leave the camera's current offset setting unchanged.
    ///   - locationId: A saved `Observatory` identifying this sequence's celestial-context FITS
    ///     headers, best-effort.
    /// - Returns: A ``ScriptRunStarted`` acknowledging the newly started run, including whether
    ///   it's `pausable`.
    /// - Throws: `INDIMCPClientError.toolCallFailed` if `rigId` is unknown to the server or the
    ///   server rejects the run (e.g. `filterName` doesn't match a configured slot), or another
    ///   `INDIMCPClientError` case on a transport/connection failure.
    public func captureFlatSequence(
        rigId: String,
        filterName: String,
        focusPosition: Int,
        exposureSeconds: Double,
        count: Int,
        gain: Double? = nil,
        offset: Double? = nil,
        locationId: String? = nil
    ) async throws -> ScriptRunStarted {
        var parameters: [String: Value] = [
            "filterName": .string(filterName),
            "focusPosition": .int(focusPosition),
            "exposureSeconds": .double(exposureSeconds),
            "count": .int(count),
        ]
        if let gain {
            parameters["gain"] = .double(gain)
        }
        if let offset {
            parameters["offset"] = .double(offset)
        }
        return try await runScript(
            scriptId: "capture_flat_sequence",
            rigId: rigId,
            parameters: parameters,
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
}

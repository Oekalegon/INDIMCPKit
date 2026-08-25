import MCP

extension INDIMCPClient {
    /// `run_calibration_sweep(kind, rig_id, ...)`, shared by `runSensorCalibrationSweep`/
    /// `runFlatCalibrationSweep` — replaces the old dedicated `run_sensor_calibration_sweep`/
    /// `run_flat_calibration_sweep` tools (INDIMCP-118).
    ///
    /// Uses `callToolUnion`, not `callTool`: `run_calibration_sweep`'s declared Python return
    /// type, `SensorCalibrationSweepStarted | FlatCalibrationSweepStarted`, is a `Union` FastMCP
    /// wraps as `{"result": ...}` the same way it does for a bare list, regardless of whether the
    /// union's members are `TypedDict`s or Pydantic models (IMCPKIT-61).
    func runCalibrationSweepTool<Output: Decodable & Sendable>(
        kind: String,
        rigId: String,
        extra: [String: Value],
        locationId: String?,
        decoding type: Output.Type
    ) async throws -> Output {
        var arguments: [String: Value] = ["kind": .string(kind), "rig_id": .string(rigId)]
        arguments.merge(extra) { _, new in new }
        if let locationId {
            arguments["location_id"] = .string(locationId)
        }
        return try await callToolUnion("run_calibration_sweep", arguments: arguments, decoding: Output.self)
    }

    /// `manage_calibration_sweep(sweep_id, action)`, shared by the get-status/cancel methods for
    /// both sensor and flat sweeps — replaces the old dedicated
    /// `get_sensor_calibration_sweep_status`/`cancel_sensor_calibration_sweep`/
    /// `get_flat_calibration_sweep_status`/`cancel_flat_calibration_sweep` tools (INDIMCP-118).
    ///
    /// Uses `callToolUnion`: `manage_calibration_sweep`'s declared return type,
    /// `SensorCalibrationSweepStatus | FlatCalibrationSweepStatus`, is also a `Union` FastMCP
    /// wraps (IMCPKIT-61).
    func manageCalibrationSweepTool<Output: Decodable & Sendable>(
        sweepId: String,
        action: String,
        decoding type: Output.Type
    ) async throws -> Output {
        try await callToolUnion(
            "manage_calibration_sweep",
            arguments: ["sweep_id": .string(sweepId), "action": .string(action)],
            decoding: Output.self
        )
    }
}

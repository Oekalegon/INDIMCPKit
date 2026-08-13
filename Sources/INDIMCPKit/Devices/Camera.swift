/// A rig-scoped handle for the `camera`-role component of a saved rig.
///
/// Obtained via `INDIMCPClient.camera(rigId:)`, not constructed directly. See `Mount`'s doc
/// comment for the connectivity-check behavior shared by every device-type handle.
public struct Camera: DeviceHandle {
    public let client: INDIMCPClient
    public let rigId: String
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
}

extension INDIMCPClient {
    /// A handle for rig `rigId`'s `camera`-role component.
    public func camera(rigId: String) -> Camera {
        Camera(client: self, rigId: rigId)
    }
}

import INDIMCPKit
import Observation

/// Backs `CameraView` — owns the `Camera` handle and its `CommandRunner`, and tracks connection/
/// cooler state so the view can gate its buttons without holding that logic itself. Mirrors
/// `AppModel`/`ServerControlModel`'s split: views bind to a model, they don't run async device
/// logic inline.
@MainActor
@Observable
final class CameraModel {
    let camera: Camera
    let runner: CommandRunner

    private(set) var isConnected = false

    /// Optimistically flipped the instant `coolCamera`/`coolerOn`/`coolerOff` is called — each of
    /// those scripts' very first step is the `CCD_COOLER` switch itself, so the outcome is known
    /// before the run (which can then run for minutes, e.g. `coolCamera` waiting on temperature)
    /// finishes. `refreshDeviceState` corrects this from the server once the run completes, in
    /// case the command failed before even reaching that step.
    private(set) var isCoolerOn: Bool?

    init(client: INDIMCPClient, rigId: String) {
        self.camera = client.camera(rigId: rigId)
        self.runner = CommandRunner(client: client)
    }

    func refreshDeviceState() async {
        async let connected = camera.isConnected()
        async let coolerOn = camera.isCoolerOn()
        isConnected = (try? await connected) ?? isConnected
        isCoolerOn = (try? await coolerOn) ?? isCoolerOn
    }

    func connect() async { await run(camera.connect) }
    func disconnect() async { await run(camera.disconnect) }

    func coolCamera(targetTempC: Double) async {
        isCoolerOn = true
        await run { try await self.camera.coolCamera(targetTempC: targetTempC) }
    }

    func coolerOn() async {
        isCoolerOn = true
        await run(camera.coolerOn)
    }

    /// Not gated on `runner.isBusy` by its `CameraView` caller like the other commands: this is
    /// the operator's way to stop an in-progress `coolCamera` run (which can legitimately take
    /// minutes) — cancelling that run doesn't itself turn the cooler back off, this does.
    func coolerOff() async {
        isCoolerOn = false
        await run(camera.coolerOff)
    }

    func captureFrame(exposureSeconds: Double) async {
        await run { try await self.camera.captureFrame(exposureSeconds: exposureSeconds) }
    }

    func cancel() async { await runner.cancel() }

    private func run(_ start: @escaping @Sendable () async throws -> ScriptRunStarted) async {
        await runner.run(start)
        await refreshDeviceState()
    }
}

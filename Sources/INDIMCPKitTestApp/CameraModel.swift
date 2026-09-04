import INDIMCPKit
import Observation

/// Backs `CameraView` — owns the `Camera` handle, its `CommandRunner`, and the `ObservableDevice`
/// that `isConnected`/`isCoolerOn` derive from, so the view can gate its buttons without holding
/// that logic itself. Mirrors `AppModel`/`ServerControlModel`'s split: views bind to a model, they
/// don't run async device logic inline.
@MainActor
@Observable
final class CameraModel {
    let camera: Camera
    let runner: CommandRunner
    let observableDevice: ObservableDevice

    /// Optimistically flipped the instant `coolCamera`/`coolerOn`/`coolerOff` is called — each of
    /// those scripts' very first step is the `CCD_COOLER` switch itself, so the outcome is known
    /// before the run (which can then run for minutes, e.g. `coolCamera` waiting on temperature)
    /// finishes. Only a fallback: `isCoolerOn` prefers `observableDevice`'s live `CCD_COOLER`
    /// reading the moment that's available, which also picks up the cooler being toggled
    /// externally (e.g. in Ekos) — something this optimistic guess alone could never reflect
    /// (IMCPKIT-28).
    private var optimisticCoolerOn: Bool?

    init(client: INDIMCPClient, rigId: String) {
        self.camera = client.camera(rigId: rigId)
        self.runner = CommandRunner(client: client)
        self.observableDevice = ObservableDevice(client: client, rigId: rigId, role: .camera)
    }

    /// Whether the rig's camera component is connected, read live from `observableDevice`'s
    /// `CONNECTION` property. `false` (not `nil`) before `observableDevice` has taken its first
    /// snapshot — the same "not yet known, so gate on not-connected" default `CameraView`'s button
    /// disabling already relied on.
    var isConnected: Bool { observableDevice.liveIsConnected ?? false }

    /// Whether the cooler is on. Prefers `observableDevice`'s live `CCD_COOLER` reading, falling
    /// back to `optimisticCoolerOn`'s instant local guess only while that live reading isn't
    /// available yet — see `optimisticCoolerOn`'s doc comment.
    var isCoolerOn: Bool? { Camera.coolerOn(from: observableDevice.properties) ?? optimisticCoolerOn }

    func connect() async { await run(camera.connect) }
    func disconnect() async { await run(camera.disconnect) }

    func coolCamera(targetTempC: Double) async {
        optimisticCoolerOn = true
        await run { try await self.camera.coolCamera(targetTempC: targetTempC) }
    }

    func coolerOn() async {
        optimisticCoolerOn = true
        await run(camera.coolerOn)
    }

    /// Not gated on `runner.isBusy` by its `CameraView` caller like the other commands: this is
    /// the operator's way to stop an in-progress `coolCamera` run (which can legitimately take
    /// minutes) — cancelling that run doesn't itself turn the cooler back off, this does.
    func coolerOff() async {
        optimisticCoolerOn = false
        await run(camera.coolerOff)
    }

    func captureFrame(exposureSeconds: Double) async {
        await run { try await self.camera.captureFrame(exposureSeconds: exposureSeconds) }
    }

    func cancel() async { await runner.cancel() }

    /// Clears `optimisticCoolerOn` if `start` didn't itself reach `ScriptRunStatus.completed`: a
    /// failed (or cancelled/paused/rejected) run may never have reached its `CCD_COOLER` step at
    /// all, so `observableDevice` has nothing to correct the guess with (no property actually
    /// changed server-side) — leaving it set would report a cooler state known to be wrong,
    /// indefinitely, until something unrelated happens to resync CCD_COOLER. On success, the guess
    /// is left in place until `observableDevice`'s live reading supersedes it, per `isCoolerOn`'s
    /// doc comment.
    ///
    /// Uses `runner.run`'s own return value for this rather than inspecting `runner.state`
    /// afterward: `state` is shared across overlapping calls (`coolerOff()` deliberately isn't
    /// gated on `runner.isBusy`, so it can interrupt an in-progress `coolCamera()` — see
    /// `CommandRunner.cancel()`'s doc comment), so by the time this call resumes, `state` could
    /// already reflect a *different*, newer call's progress rather than this one's own outcome.
    private func run(_ start: @escaping @Sendable () async throws -> ScriptRunStarted) async {
        let succeeded = await runner.run(start)
        if !succeeded {
            optimisticCoolerOn = nil
        }
    }
}

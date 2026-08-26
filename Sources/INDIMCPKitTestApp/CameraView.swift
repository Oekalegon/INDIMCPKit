import INDIMCPKit
import SwiftUI

/// Camera control screen — binds to `CameraModel`, which owns the `Camera` handle, `CommandRunner`,
/// and the `ObservableDevice`/optimistic-guess state its `isConnected`/`isCoolerOn` derive from
/// (see `CameraModel`'s doc comment). Unlike `MountView`/`FocuserView`/`FilterWheelView`, which own
/// their device handle and runner directly, this view needs that extra state, hence the model.
struct CameraView: View {
    @State private var model: CameraModel
    @State private var targetTempC = "-10"
    @State private var exposureSeconds = "1"
    let isActive: Bool

    init(client: INDIMCPClient, rigId: String, isActive: Bool) {
        _model = State(initialValue: CameraModel(client: client, rigId: rigId))
        self.isActive = isActive
    }

    var body: some View {
        Form {
            Section("Connection") {
                HStack {
                    Button("Connect") { Task { await model.connect() } }
                    Button("Disconnect") { Task { await model.disconnect() } }
                }
            }
            .disabled(model.runner.isBusy)

            Section("Cooling") {
                TextField("Target temperature (°C)", text: $targetTempC)
                HStack {
                    Button("Cool Camera") {
                        Task { await model.coolCamera(targetTempC: Double(targetTempC) ?? -10) }
                    }
                    .disabled(!model.isConnected || model.isCoolerOn == true)

                    Button("Cooler On") { Task { await model.coolerOn() } }
                        .disabled(!model.isConnected || model.isCoolerOn == true)

                    Button("Cooler Off") { Task { await model.coolerOff() } }
                        .disabled(!model.isConnected || model.isCoolerOn == false)
                }
            }

            Section("Exposure") {
                TextField("Exposure (seconds)", text: $exposureSeconds)
                Button("Capture Frame") {
                    Task { await model.captureFrame(exposureSeconds: Double(exposureSeconds) ?? 1) }
                }
            }
            .disabled(model.runner.isBusy || !model.isConnected)

            Section("Status") {
                CommandStatusView(state: model.runner.state) { Task { await model.cancel() } }
            }

            DevicePropertiesSection(
                properties: model.observableDevice.properties,
                isRefreshed: model.observableDevice.isRefreshed,
                lastError: model.observableDevice.lastError
            )
        }
        .padding()
        .navigationTitle("Camera")
        // Scoped to isActive (whether this is the currently selected tab), not just view
        // lifecycle: TabView on macOS keeps every tab's content view alive in the hierarchy the
        // whole time the TabView exists, so onDisappear alone would never fire on a tab switch —
        // only on disconnect/change rig. .task(id:) re-runs (cancelling the previous run) whenever
        // isActive changes, so the live subscription only stays open while this tab is the one
        // actually visible, not for every tab simultaneously for the whole session.
        .task(id: isActive) {
            if isActive {
                await model.observableDevice.start()
            } else {
                await model.observableDevice.stop()
            }
        }
        .onDisappear { Task { await model.observableDevice.stop() } }
    }
}

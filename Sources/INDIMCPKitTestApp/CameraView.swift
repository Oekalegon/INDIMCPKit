import INDIMCPKit
import SwiftUI

struct CameraView: View {
    @State private var model: CameraModel
    @State private var targetTempC = "-10"
    @State private var exposureSeconds = "1"

    init(client: INDIMCPClient, rigId: String) {
        _model = State(initialValue: CameraModel(client: client, rigId: rigId))
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
        .task { await model.refreshDeviceState() }
        // Not scoped to "while this tab is visible": TabView on macOS keeps every tab's content
        // view alive in the hierarchy the whole time the TabView exists, so switching away from
        // this tab doesn't trigger onDisappear — only disconnecting/changing rig does. This
        // subscription (and the same one on every other device tab) runs for the whole connected
        // session, not just while the operator is actually looking at it.
        .task { await model.observableDevice.start() }
        .onDisappear { model.observableDevice.stop() }
    }
}

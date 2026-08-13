import INDIMCPKit
import SwiftUI

struct CameraView: View {
    let camera: Camera

    @State private var runner: CommandRunner
    @State private var isConnected = false
    @State private var targetTempC = "-10"
    @State private var exposureSeconds = "1"

    init(client: INDIMCPClient, rigId: String) {
        self.camera = client.camera(rigId: rigId)
        _runner = State(initialValue: CommandRunner(client: client))
    }

    var body: some View {
        Form {
            Section("Connection") {
                HStack {
                    Button("Connect") { Task { await run(camera.connect) } }
                    Button("Disconnect") { Task { await run(camera.disconnect) } }
                }
            }
            .disabled(runner.isBusy)

            Section("Cooling") {
                TextField("Target temperature (°C)", text: $targetTempC)
                HStack {
                    Button("Cool Camera") {
                        Task {
                            await run {
                                try await camera.coolCamera(targetTempC: Double(targetTempC) ?? -10)
                            }
                        }
                    }
                    Button("Cooler On") { Task { await run(camera.coolerOn) } }
                    Button("Cooler Off") { Task { await run(camera.coolerOff) } }
                }
            }
            .disabled(runner.isBusy || !isConnected)

            Section("Exposure") {
                TextField("Exposure (seconds)", text: $exposureSeconds)
                Button("Capture Frame") {
                    Task {
                        await run {
                            try await camera.captureFrame(exposureSeconds: Double(exposureSeconds) ?? 1)
                        }
                    }
                }
            }
            .disabled(runner.isBusy || !isConnected)

            Section("Status") {
                CommandStatusView(state: runner.state) { Task { await runner.cancel() } }
            }
        }
        .padding()
        .navigationTitle("Camera")
        .task { await refreshConnectionState() }
    }

    private func run(_ start: @escaping @Sendable () async throws -> ScriptRunStarted) async {
        await runner.run(start)
        await refreshConnectionState()
    }

    private func refreshConnectionState() async {
        isConnected = (try? await camera.isConnected()) ?? isConnected
    }
}

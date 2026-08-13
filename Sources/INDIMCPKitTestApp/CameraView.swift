import INDIMCPKit
import SwiftUI

struct CameraView: View {
    let camera: Camera

    @State private var runner: CommandRunner
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
                    Button("Connect") { Task { await runner.run(camera.connect) } }
                    Button("Disconnect") { Task { await runner.run(camera.disconnect) } }
                }
            }

            Section("Cooling") {
                TextField("Target temperature (°C)", text: $targetTempC)
                HStack {
                    Button("Cool Camera") {
                        Task {
                            await runner.run {
                                try await camera.coolCamera(targetTempC: Double(targetTempC) ?? -10)
                            }
                        }
                    }
                    Button("Cooler On") { Task { await runner.run(camera.coolerOn) } }
                    Button("Cooler Off") { Task { await runner.run(camera.coolerOff) } }
                }
            }

            Section("Exposure") {
                TextField("Exposure (seconds)", text: $exposureSeconds)
                Button("Capture Frame") {
                    Task {
                        await runner.run {
                            try await camera.captureFrame(exposureSeconds: Double(exposureSeconds) ?? 1)
                        }
                    }
                }
            }

            Section("Status") {
                CommandStatusView(state: runner.state)
            }
        }
        .padding()
        .navigationTitle("Camera")
    }
}

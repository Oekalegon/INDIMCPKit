import INDIMCPKit
import SwiftUI

struct FocuserView: View {
    let focuser: Focuser

    @State private var runner: CommandRunner
    @State private var isConnected = false
    @State private var position = "0"

    init(client: INDIMCPClient, rigId: String) {
        self.focuser = client.focuser(rigId: rigId)
        _runner = State(initialValue: CommandRunner(client: client))
    }

    var body: some View {
        Form {
            Section("Connection") {
                HStack {
                    Button("Connect") { Task { await run(focuser.connect) } }
                    Button("Disconnect") { Task { await run(focuser.disconnect) } }
                }
            }
            .disabled(runner.isBusy)

            Section("Position") {
                TextField("Absolute position", text: $position)
                Button("Set Focus Position") {
                    Task {
                        await run {
                            try await focuser.setFocusPosition(Int(position) ?? 0)
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
        .navigationTitle("Focuser")
        .task { await refreshConnectionState() }
    }

    private func run(_ start: @escaping @Sendable () async throws -> ScriptRunStarted) async {
        await runner.run(start)
        await refreshConnectionState()
    }

    private func refreshConnectionState() async {
        isConnected = (try? await focuser.isConnected()) ?? isConnected
    }
}

import INDIMCPKit
import SwiftUI

struct MountView: View {
    let mount: Mount

    @State private var runner: CommandRunner
    @State private var isConnected = false
    @State private var ra = "0"
    @State private var dec = "0"

    init(client: INDIMCPClient, rigId: String) {
        self.mount = client.mount(rigId: rigId)
        _runner = State(initialValue: CommandRunner(client: client))
    }

    var body: some View {
        Form {
            Section("Connection") {
                HStack {
                    Button("Connect") { Task { await run(mount.connect) } }
                    Button("Disconnect") { Task { await run(mount.disconnect) } }
                }
            }
            .disabled(runner.isBusy)

            Section("Park / Track") {
                HStack {
                    Button("Park") { Task { await run(mount.park) } }
                    Button("Unpark") { Task { await run(mount.unpark) } }
                    Button("Track Off") { Task { await run(mount.trackOff) } }
                }
            }
            .disabled(runner.isBusy || !isConnected)

            Section("Slew") {
                TextField("RA (hours)", text: $ra)
                TextField("Dec (degrees)", text: $dec)
                Button("Slew") {
                    Task {
                        await run {
                            try await mount.slew(ra: Double(ra) ?? 0, dec: Double(dec) ?? 0)
                        }
                    }
                }
            }
            .disabled(runner.isBusy || !isConnected)

            Section("Status") {
                CommandStatusView(state: runner.state)
            }
        }
        .padding()
        .navigationTitle("Mount")
        .task { await refreshConnectionState() }
    }

    private func run(_ start: @escaping @Sendable () async throws -> ScriptRunStarted) async {
        await runner.run(start)
        await refreshConnectionState()
    }

    private func refreshConnectionState() async {
        isConnected = (try? await mount.isConnected()) ?? isConnected
    }
}

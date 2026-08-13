import INDIMCPKit
import SwiftUI

struct MountView: View {
    let mount: Mount

    @State private var runner: CommandRunner
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
                    Button("Connect") { Task { await runner.run(mount.connect) } }
                    Button("Disconnect") { Task { await runner.run(mount.disconnect) } }
                }
            }

            Section("Park / Track") {
                HStack {
                    Button("Park") { Task { await runner.run(mount.park) } }
                    Button("Unpark") { Task { await runner.run(mount.unpark) } }
                    Button("Track Off") { Task { await runner.run(mount.trackOff) } }
                }
            }

            Section("Slew") {
                TextField("RA (hours)", text: $ra)
                TextField("Dec (degrees)", text: $dec)
                Button("Slew") {
                    Task {
                        await runner.run {
                            try await mount.slew(ra: Double(ra) ?? 0, dec: Double(dec) ?? 0)
                        }
                    }
                }
            }

            Section("Status") {
                CommandStatusView(state: runner.state)
            }
        }
        .padding()
        .navigationTitle("Mount")
    }
}

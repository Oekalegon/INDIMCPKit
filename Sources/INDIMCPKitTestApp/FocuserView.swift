import INDIMCPKit
import SwiftUI

struct FocuserView: View {
    let focuser: Focuser

    @State private var runner: CommandRunner
    @State private var position = "0"

    init(client: INDIMCPClient, rigId: String) {
        self.focuser = client.focuser(rigId: rigId)
        _runner = State(initialValue: CommandRunner(client: client))
    }

    var body: some View {
        Form {
            Section("Connection") {
                HStack {
                    Button("Connect") { Task { await runner.run(focuser.connect) } }
                    Button("Disconnect") { Task { await runner.run(focuser.disconnect) } }
                }
            }
            .disabled(runner.isBusy)

            Section("Position") {
                TextField("Absolute position", text: $position)
                Button("Set Focus Position") {
                    Task {
                        await runner.run {
                            try await focuser.setFocusPosition(Int(position) ?? 0)
                        }
                    }
                }
            }
            .disabled(runner.isBusy)

            Section("Status") {
                CommandStatusView(state: runner.state)
            }
        }
        .padding()
        .navigationTitle("Focuser")
    }
}

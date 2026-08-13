import INDIMCPKit
import SwiftUI

struct FilterWheelView: View {
    let filterWheel: FilterWheel

    @State private var runner: CommandRunner
    @State private var filterName = ""

    init(client: INDIMCPClient, rigId: String) {
        self.filterWheel = client.filterWheel(rigId: rigId)
        _runner = State(initialValue: CommandRunner(client: client))
    }

    var body: some View {
        Form {
            Section("Connection") {
                HStack {
                    Button("Connect") { Task { await runner.run(filterWheel.connect) } }
                    Button("Disconnect") { Task { await runner.run(filterWheel.disconnect) } }
                }
            }
            .disabled(runner.isBusy)

            Section("Filter") {
                TextField("Filter name", text: $filterName)
                Button("Select Filter") {
                    Task { await runner.run { try await filterWheel.selectFilter(filterName) } }
                }
                .disabled(filterName.isEmpty || runner.isBusy)
            }

            Section("Status") {
                CommandStatusView(state: runner.state)
            }
        }
        .padding()
        .navigationTitle("Filter Wheel")
    }
}

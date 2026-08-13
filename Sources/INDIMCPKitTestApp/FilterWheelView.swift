import INDIMCPKit
import SwiftUI

struct FilterWheelView: View {
    let filterWheel: FilterWheel

    @State private var runner: CommandRunner
    @State private var isConnected = false
    @State private var filterName = ""

    init(client: INDIMCPClient, rigId: String) {
        self.filterWheel = client.filterWheel(rigId: rigId)
        _runner = State(initialValue: CommandRunner(client: client))
    }

    var body: some View {
        Form {
            Section("Connection") {
                HStack {
                    Button("Connect") { Task { await run(filterWheel.connect) } }
                    Button("Disconnect") { Task { await run(filterWheel.disconnect) } }
                }
            }
            .disabled(runner.isBusy)

            Section("Filter") {
                TextField("Filter name", text: $filterName)
                Button("Select Filter") {
                    Task { await run { try await filterWheel.selectFilter(filterName) } }
                }
                .disabled(filterName.isEmpty || runner.isBusy || !isConnected)
            }

            Section("Status") {
                CommandStatusView(state: runner.state)
            }
        }
        .padding()
        .navigationTitle("Filter Wheel")
        .task { await refreshConnectionState() }
    }

    private func run(_ start: @escaping @Sendable () async throws -> ScriptRunStarted) async {
        await runner.run(start)
        await refreshConnectionState()
    }

    private func refreshConnectionState() async {
        isConnected = (try? await filterWheel.isConnected()) ?? isConnected
    }
}

import INDIMCPKit
import SwiftUI

struct FilterWheelView: View {
    let filterWheel: FilterWheel

    @State private var runner: CommandRunner
    @State private var observableDevice: ObservableDevice
    @State private var isConnected = false
    @State private var filterName = ""

    init(client: INDIMCPClient, rigId: String) {
        self.filterWheel = client.filterWheel(rigId: rigId)
        _runner = State(initialValue: CommandRunner(client: client))
        _observableDevice = State(initialValue: ObservableDevice(client: client, rigId: rigId, role: .filterWheel))
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
                CommandStatusView(state: runner.state) { Task { await runner.cancel() } }
            }

            DevicePropertiesSection(
                properties: observableDevice.properties,
                isRefreshed: observableDevice.isRefreshed,
                lastError: observableDevice.lastError
            )
        }
        .padding()
        .navigationTitle("Filter Wheel")
        .task { await refreshConnectionState() }
        // Not scoped to "while this tab is visible": TabView on macOS keeps every tab's content
        // view alive in the hierarchy the whole time the TabView exists, so switching away from
        // this tab doesn't trigger onDisappear — only disconnecting/changing rig does. This
        // subscription (and the same one on every other device tab) runs for the whole connected
        // session, not just while the operator is actually looking at it.
        .task { await observableDevice.start() }
        .onDisappear { observableDevice.stop() }
    }

    private func run(_ start: @escaping @Sendable () async throws -> ScriptRunStarted) async {
        await runner.run(start)
        await refreshConnectionState()
    }

    private func refreshConnectionState() async {
        isConnected = (try? await filterWheel.isConnected()) ?? isConnected
    }
}

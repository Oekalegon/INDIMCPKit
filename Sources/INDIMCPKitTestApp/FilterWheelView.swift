import INDIMCPKit
import SwiftUI

/// Filter wheel control screen — owns the `FilterWheel` handle, its `CommandRunner`, and its
/// `ObservableDevice` subscription directly (no separate model, unlike `CameraView`/`CameraModel`)
/// since there's no derived state to track beyond what those two already publish.
struct FilterWheelView: View {
    let filterWheel: FilterWheel

    @State private var runner: CommandRunner
    @State private var observableDevice: ObservableDevice
    @State private var isConnected = false
    @State private var filterName = ""
    let isActive: Bool

    init(client: INDIMCPClient, rigId: String, isActive: Bool) {
        self.filterWheel = client.filterWheel(rigId: rigId)
        _runner = State(initialValue: CommandRunner(client: client))
        _observableDevice = State(initialValue: ObservableDevice(client: client, rigId: rigId, role: .filterWheel))
        self.isActive = isActive
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
        // Scoped to isActive (whether this is the currently selected tab), not just view
        // lifecycle: TabView on macOS keeps every tab's content view alive in the hierarchy the
        // whole time the TabView exists, so onDisappear alone would never fire on a tab switch —
        // only on disconnect/change rig. .task(id:) re-runs (cancelling the previous run) whenever
        // isActive changes, so the live subscription only stays open while this tab is the one
        // actually visible, not for every tab simultaneously for the whole session.
        .task(id: isActive) {
            if isActive {
                await observableDevice.start()
            } else {
                await observableDevice.stop()
            }
        }
        .onDisappear { Task { await observableDevice.stop() } }
    }

    private func run(_ start: @escaping @Sendable () async throws -> ScriptRunStarted) async {
        await runner.run(start)
        await refreshConnectionState()
    }

    private func refreshConnectionState() async {
        isConnected = (try? await filterWheel.isConnected()) ?? isConnected
    }
}

import INDIMCPKit
import SwiftUI

/// Focuser control screen — owns the `Focuser` handle, its `CommandRunner`, and its
/// `ObservableDevice` subscription directly (no separate model, unlike `CameraView`/`CameraModel`)
/// since its own state (just `isConnected`) is a single value refreshed after each command, not
/// the multi-step cooler-state coordination `CameraModel` exists for.
struct FocuserView: View {
    let focuser: Focuser

    @State private var runner: CommandRunner
    @State private var observableDevice: ObservableDevice
    @State private var isConnected = false
    @State private var position = "0"
    let isActive: Bool

    init(client: INDIMCPClient, rigId: String, isActive: Bool) {
        self.focuser = client.focuser(rigId: rigId)
        _runner = State(initialValue: CommandRunner(client: client))
        _observableDevice = State(initialValue: ObservableDevice(client: client, rigId: rigId, role: .focuser))
        self.isActive = isActive
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

            DevicePropertiesSection(
                properties: observableDevice.properties,
                isRefreshed: observableDevice.isRefreshed,
                lastError: observableDevice.lastError
            )
        }
        .padding()
        .navigationTitle("Focuser")
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
        isConnected = (try? await focuser.isConnected()) ?? isConnected
    }
}

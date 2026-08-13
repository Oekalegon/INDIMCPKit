import INDIMCPKit
import SwiftUI

struct MountView: View {
    let mount: Mount

    @State private var runner: CommandRunner
    @State private var observableDevice: ObservableDevice
    @State private var isConnected = false
    @State private var ra = "0"
    @State private var dec = "0"
    let isActive: Bool

    init(client: INDIMCPClient, rigId: String, isActive: Bool) {
        self.mount = client.mount(rigId: rigId)
        _runner = State(initialValue: CommandRunner(client: client))
        _observableDevice = State(initialValue: ObservableDevice(client: client, rigId: rigId, role: .mount))
        self.isActive = isActive
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

            // Deliberately not gated on runner.isBusy like the Slew section below: this is the
            // operator's way to override an in-progress Slew (which has no give-up bound — see
            // CommandRunner's doc comment) — needing to hit Park immediately while slewing toward
            // an obstruction is exactly the kind of hardware-safety override this app should never
            // block. Pressing Park/Unpark/Track Off cancels watching the slew (CommandRunner.run's
            // existing supersession behavior) and starts watching the new command instead; the
            // slew keeps running server-side until its own step naturally resolves, same trade-off
            // already accepted for Camera's Cooler Off override.
            Section("Park / Track") {
                HStack {
                    Button("Park") { Task { await run(mount.park) } }
                    Button("Unpark") { Task { await run(mount.unpark) } }
                    Button("Track Off") { Task { await run(mount.trackOff) } }
                }
            }
            .disabled(!isConnected)

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
                CommandStatusView(state: runner.state) { Task { await runner.cancel() } }
            }

            DevicePropertiesSection(
                properties: observableDevice.properties,
                isRefreshed: observableDevice.isRefreshed,
                lastError: observableDevice.lastError
            )
        }
        .padding()
        .navigationTitle("Mount")
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
                observableDevice.stop()
            }
        }
        .onDisappear { observableDevice.stop() }
    }

    private func run(_ start: @escaping @Sendable () async throws -> ScriptRunStarted) async {
        await runner.run(start)
        await refreshConnectionState()
    }

    private func refreshConnectionState() async {
        isConnected = (try? await mount.isConnected()) ?? isConnected
    }
}

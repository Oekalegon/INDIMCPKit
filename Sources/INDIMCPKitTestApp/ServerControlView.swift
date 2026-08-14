import INDIMCPKit
import SwiftUI

/// Manual control over `indiserver`, the messaging stream, and individual INDI drivers — the
/// prerequisites every device screen's connect/command calls silently depend on. `AppModel`
/// auto-starts the server and messaging stream on connect (best-effort, without restarting an
/// already-running session), but starting the specific driver for a device is inherently a choice
/// only the operator can make, so that's manual-only here.
struct ServerControlView: View {
    @State private var model: ServerControlModel

    init(client: INDIMCPClient, rigId: String) {
        _model = State(initialValue: ServerControlModel(client: client, rigId: rigId))
    }

    var body: some View {
        Form {
            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            Section("INDI Server") {
                LabeledContent("Status", value: statusText(model.serverStatus?.running))
                if let port = model.serverStatus?.port {
                    LabeledContent("Port", value: "\(port)")
                }
                HStack {
                    Button("Start") { Task { await model.startServer() } }
                        .disabled(model.isBusy || model.serverStatus?.running == true)
                    Button("Stop") { Task { await model.stopServer() } }
                        .disabled(model.isBusy || model.serverStatus?.running != true)
                    Button("Restart") { Task { await model.restartServer() } }
                        .disabled(model.isBusy)
                }
            }

            Section("Messaging") {
                LabeledContent("Status", value: statusText(model.messagingStatus?.running))
                if let messagingStatus = model.messagingStatus {
                    LabeledContent("Host", value: "\(messagingStatus.host):\(messagingStatus.port)")
                }
                HStack {
                    Button("Start") { Task { await model.startMessaging() } }
                        .disabled(model.isBusy || model.messagingStatus?.running == true)
                    Button("Stop") { Task { await model.stopMessaging() } }
                        .disabled(model.isBusy || model.messagingStatus?.running != true)
                }
            }

            Section("This Rig's Drivers") {
                if model.isLoading {
                    Text("Loading…")
                        .foregroundStyle(.secondary)
                } else if rigDrivers.isEmpty {
                    Text("No component in this rig has a device name set, or none of them are in the driver catalog.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(rigDrivers, id: \.label) { driver in
                        driverRow(driver)
                    }
                }
            }

            if !otherDrivers.isEmpty {
                Section {
                    DisclosureGroup("Other Installed Drivers (\(otherDrivers.count))") {
                        ForEach(otherDrivers, id: \.label) { driver in
                            driverRow(driver)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("Refresh") { Task { await model.refresh() } }
                    .disabled(model.isLoading || model.isBusy)
            }
        }
        .task { await model.refresh() }
    }

    private var rigDrivers: [DriverInfo] {
        model.driverCatalog.filter { $0.installed && model.rigDeviceLabels.contains($0.label) }
    }

    private var otherDrivers: [DriverInfo] {
        model.driverCatalog.filter { $0.installed && !model.rigDeviceLabels.contains($0.label) }
    }

    @ViewBuilder
    private func driverRow(_ driver: DriverInfo) -> some View {
        let running = model.isDriverRunning(label: driver.label)
        HStack {
            VStack(alignment: .leading) {
                Text(driver.label)
                Text(driver.family)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(running ? "Stop" : "Start") {
                Task {
                    if running {
                        await model.stopDriver(label: driver.label)
                    } else {
                        await model.startDriver(label: driver.label)
                    }
                }
            }
            .disabled(model.isBusy)
        }
    }

    private func statusText(_ running: Bool?) -> String {
        guard let running else { return "Unknown" }
        return running ? "Running" : "Stopped"
    }
}

import INDIMCPKit
import SwiftUI

/// Live view of the `indi://messages` event stream (IMCPKIT-14, IMCPKIT-19) — every
/// INDI property/message event as it arrives, newest first, optionally scoped to one device via
/// a picker sourced from the rig's own components.
struct MessageStreamView: View {
    @State private var model: MessageStreamModel
    @State private var selectedDevice: String?
    let isActive: Bool

    init(client: INDIMCPClient, rigId: String, isActive: Bool) {
        _model = State(initialValue: MessageStreamModel(client: client, rigId: rigId))
        self.isActive = isActive
    }

    var body: some View {
        Form {
            if let lastError = model.lastError {
                Text(lastError)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            Section("Scope") {
                Picker("Device", selection: $selectedDevice) {
                    Text("All Devices").tag(String?.none)
                    ForEach(model.deviceOptions, id: \.self) { device in
                        Text(device).tag(String?.some(device))
                    }
                }
            }

            Section("Events (\(model.events.count))") {
                if model.events.isEmpty {
                    Text("No events received yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    // Bounded and independently scrollable, same reasoning as
                    // DevicePropertiesSection: the server's own rolling window is already capped,
                    // but a Form-embedded, unbounded ForEach would still push everything else on
                    // this screen off-screen as it fills up.
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(model.events.enumerated()), id: \.offset) { _, event in
                                eventRow(event)
                                Divider()
                            }
                        }
                    }
                    .frame(maxHeight: 500)
                    .textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Messages")
        .task { await model.loadDeviceOptions() }
        // Scoped to isActive, not just view lifecycle — see CameraView's identical .task(id:) for
        // why TabView on macOS needs this rather than onDisappear alone. Also re-runs whenever
        // selectedDevice changes, so switching the picker restarts the subscription scoped to the
        // newly selected device.
        .task(id: TaskID(isActive: isActive, device: selectedDevice)) {
            if isActive {
                model.start(device: selectedDevice)
            } else {
                model.stop()
            }
        }
        .onDisappear { model.stop() }
    }

    /// `.task(id:)` requires its id to be `Equatable`; a plain tuple isn't, so this wraps the two
    /// values `start(device:)` actually needs to know changed.
    private struct TaskID: Equatable {
        let isActive: Bool
        let device: String?
    }

    private func eventRow(_ event: IndiEvent) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if let state = event.state {
                    Circle()
                        .fill(color(for: state))
                        .frame(width: 8, height: 8)
                        .help(state.rawValue)
                }
                Text(event.kind)
                    .font(.subheadline.bold())
                if let type = event.type {
                    Text(type)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(event.timestamp)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                if let device = event.device {
                    Text(device)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let name = event.name {
                    Text(name)
                        .font(.caption.bold())
                }
            }

            if let message = event.message {
                Text(message)
                    .font(.caption)
            }

            if let elements = event.elements, !elements.isEmpty {
                ForEach(elements.sorted(by: { $0.key < $1.key }), id: \.key) { element in
                    HStack {
                        Text(element.key)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(element.value)
                            .font(.caption.monospaced())
                    }
                    .padding(.leading, 14)
                }
            }
        }
        .padding(.vertical, 3)
    }

    private func color(for state: PropertyState) -> Color {
        switch state {
        case .idle: return .gray
        case .ok: return .green
        case .busy: return .yellow
        case .alert: return .red
        case .other: return .secondary
        }
    }
}

import INDIMCPKit
import SwiftUI

struct ConnectionView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("INDIMCPKit Test App")
                .font(.title)

            Form {
                TextField("Server URL", text: $model.serverURLString)
            }
            .disabled(isConnecting)

            if case .failed(let message) = model.connectionStatus {
                Text(message)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            HStack {
                Button(isConnecting ? "Connecting…" : "Connect") {
                    Task { await model.connect() }
                }
                .disabled(isConnecting)

                if isConnecting {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            discoverySection
        }
        .padding()
        .frame(minWidth: 360)
        .onAppear { model.discovery.start() }
        .onDisappear { model.discovery.stop() }
    }

    private var isConnecting: Bool {
        model.connectionStatus == .connecting
    }

    @ViewBuilder
    private var discoverySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Discovered servers")
                    .font(.headline)
                if model.discovery.isBrowsing {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let lastError = model.discovery.lastError {
                Text(lastError)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            if model.discovery.discoveredServers.isEmpty {
                Text("No servers found yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.discovery.discoveredServers) { server in
                    Button {
                        model.serverURLString = server.endpoint.absoluteString
                    } label: {
                        VStack(alignment: .leading) {
                            Text(server.name)
                            Text(server.endpoint.absoluteString)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .disabled(isConnecting)
    }
}

#Preview {
    ConnectionView(model: AppModel())
}

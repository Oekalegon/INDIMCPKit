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
        }
        .padding()
        .frame(minWidth: 360)
    }

    private var isConnecting: Bool {
        model.connectionStatus == .connecting
    }
}

#Preview {
    ConnectionView(model: AppModel())
}

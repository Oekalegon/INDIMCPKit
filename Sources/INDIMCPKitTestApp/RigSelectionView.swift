import INDIMCPKit
import SwiftUI

/// Shown once connected, before any device screen — lists the server's configured rigs and lets
/// the operator pick one, or create a new one, rather than requiring a rig id to be typed blind
/// before even connecting.
struct RigSelectionView: View {
    @Bindable var model: AppModel

    @State private var rigs: [RigSummary] = []
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var isPresentingCreateRig = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Select a Rig")
                    .font(.title)
                Spacer()
                Button("Disconnect") {
                    Task { await model.disconnect() }
                }
            }

            if isLoading {
                ProgressView("Loading rigs…")
            } else if let loadError {
                Text(loadError)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            } else if rigs.isEmpty {
                Text("No rigs configured on this server yet.")
                    .foregroundStyle(.secondary)
            } else {
                List(rigs, id: \.id) { rig in
                    Button {
                        model.selectedRigId = rig.id
                    } label: {
                        HStack {
                            Text(rig.name)
                            Spacer()
                            Text(rig.id)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .frame(minHeight: 160)
            }

            HStack {
                Button("Refresh") {
                    Task { await loadRigs() }
                }
                .disabled(isLoading)

                Button("Create New Rig…") {
                    isPresentingCreateRig = true
                }
            }
        }
        .padding()
        .frame(minWidth: 420, minHeight: 320)
        .task { await loadRigs() }
        .sheet(isPresented: $isPresentingCreateRig) {
            CreateRigView(model: model) { newRigId in
                isPresentingCreateRig = false
                model.selectedRigId = newRigId
            }
        }
    }

    private func loadRigs() async {
        guard let client = model.client else { return }
        isLoading = true
        loadError = nil
        do {
            rigs = try await client.listRigs()
        } catch {
            loadError = String(describing: error)
        }
        isLoading = false
    }
}

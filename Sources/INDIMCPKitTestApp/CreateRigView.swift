import INDIMCPKit
import SwiftUI

/// Minimal rig-creation form — just the roles this test app actually drives
/// (`Mount`/`Camera`/`FilterWheel`/`Focuser`), each as a single optional INDI device name. A rig
/// needing more than one component per role, or roles beyond these four, should be authored on
/// the server directly; this is a convenience for standing up a quick test rig, not a full editor.
struct CreateRigView: View {
    @Bindable var model: AppModel
    let onCreated: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var rigId = ""
    @State private var name = ""
    @State private var mountDevice = ""
    @State private var cameraDevice = ""
    @State private var filterWheelDevice = ""
    @State private var focuserDevice = ""
    @State private var isSaving = false
    @State private var saveError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create New Rig")
                .font(.title2)

            Form {
                TextField("Rig ID", text: $rigId)
                TextField("Name", text: $name)
                Section("Devices (INDI driver name, leave blank to skip)") {
                    TextField("Mount", text: $mountDevice)
                    TextField("Camera", text: $cameraDevice)
                    TextField("Filter Wheel", text: $filterWheelDevice)
                    TextField("Focuser", text: $focuserDevice)
                }
            }

            if let saveError {
                Text(saveError)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button(isSaving ? "Creating…" : "Create") {
                    Task { await createRig() }
                }
                .disabled(isSaving || rigId.isEmpty || name.isEmpty)
            }
        }
        .padding()
        .frame(minWidth: 420)
    }

    private func createRig() async {
        guard let client = model.client else { return }
        isSaving = true
        saveError = nil

        var components: [Component] = []
        if !mountDevice.isEmpty {
            components.append(Component(role: .mount, id: "mount", device: mountDevice))
        }
        if !cameraDevice.isEmpty {
            components.append(Component(role: .camera, id: "camera", device: cameraDevice))
        }
        if !filterWheelDevice.isEmpty {
            components.append(Component(role: .filterWheel, id: "filterWheel", device: filterWheelDevice))
        }
        if !focuserDevice.isEmpty {
            components.append(Component(role: .focuser, id: "focuser", device: focuserDevice))
        }

        do {
            let rig = try await client.saveRig(Rig(id: rigId, name: name, components: components))
            isSaving = false
            onCreated(rig.id)
        } catch {
            saveError = String(describing: error)
            isSaving = false
        }
    }
}

import INDIMCPKit
import SwiftUI

struct ContentView: View {
    @State private var model = AppModel()

    var body: some View {
        if model.isConnected, let client = model.client, let rigId = model.selectedRigId {
            DeviceTabsView(
                client: client,
                rigId: rigId,
                onChangeRig: { model.selectedRigId = nil },
                onDisconnect: { Task { await model.disconnect() } }
            )
        } else if model.isConnected {
            RigSelectionView(model: model)
        } else {
            ConnectionView(model: model)
        }
    }
}

#Preview {
    ContentView()
}

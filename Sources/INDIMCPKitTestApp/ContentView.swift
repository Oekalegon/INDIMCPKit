import INDIMCPKit
import SwiftUI

struct ContentView: View {
    @State private var model = AppModel()

    var body: some View {
        if model.isConnected, let client = model.client {
            DeviceTabsView(client: client, rigId: model.rigId) {
                Task { await model.disconnect() }
            }
        } else {
            ConnectionView(model: model)
        }
    }
}

#Preview {
    ContentView()
}

import INDIMCPKit
import SwiftUI

/// One screen per device type, showing its default tool connections in action — see README.md's
/// planned layout for this app.
struct DeviceTabsView: View {
    let client: INDIMCPClient
    let rigId: String
    let onDisconnect: () -> Void

    var body: some View {
        TabView {
            MountView(client: client, rigId: rigId)
                .tabItem { Label("Mount", systemImage: "scope") }
            CameraView(client: client, rigId: rigId)
                .tabItem { Label("Camera", systemImage: "camera") }
            FilterWheelView(client: client, rigId: rigId)
                .tabItem { Label("Filter Wheel", systemImage: "circle.grid.3x3") }
            FocuserView(client: client, rigId: rigId)
                .tabItem { Label("Focuser", systemImage: "camera.macro") }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("Disconnect", action: onDisconnect)
            }
        }
        .frame(minWidth: 480, minHeight: 420)
    }
}

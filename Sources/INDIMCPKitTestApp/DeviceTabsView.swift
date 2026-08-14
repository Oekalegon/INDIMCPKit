import INDIMCPKit
import SwiftUI

/// One screen per device type, showing its default tool connections in action — see README.md's
/// planned layout for this app.
struct DeviceTabsView: View {
    enum Tab {
        case server, messages, frames, mount, camera, filterWheel, focuser
    }

    let client: INDIMCPClient
    let rigId: String
    let onChangeRig: () -> Void
    let onDisconnect: () -> Void

    @State private var selectedTab = Tab.server

    var body: some View {
        TabView(selection: $selectedTab) {
            ServerControlView(client: client, rigId: rigId)
                .tabItem { Label("Server", systemImage: "server.rack") }
                .tag(Tab.server)
            MessageStreamView(client: client, rigId: rigId, isActive: selectedTab == .messages)
                .tabItem { Label("Messages", systemImage: "text.bubble") }
                .tag(Tab.messages)
            FramesView(client: client)
                .tabItem { Label("Frames", systemImage: "photo.on.rectangle") }
                .tag(Tab.frames)
            MountView(client: client, rigId: rigId, isActive: selectedTab == .mount)
                .tabItem { Label("Mount", systemImage: "scope") }
                .tag(Tab.mount)
            CameraView(client: client, rigId: rigId, isActive: selectedTab == .camera)
                .tabItem { Label("Camera", systemImage: "camera") }
                .tag(Tab.camera)
            FilterWheelView(client: client, rigId: rigId, isActive: selectedTab == .filterWheel)
                .tabItem { Label("Filter Wheel", systemImage: "circle.grid.3x3") }
                .tag(Tab.filterWheel)
            FocuserView(client: client, rigId: rigId, isActive: selectedTab == .focuser)
                .tabItem { Label("Focuser", systemImage: "camera.macro") }
                .tag(Tab.focuser)
        }
        .navigationTitle("Rig: \(rigId)")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("Change Rig", action: onChangeRig)
            }
            ToolbarItem(placement: .automatic) {
                Button("Disconnect", action: onDisconnect)
            }
        }
        .frame(minWidth: 480, minHeight: 420)
    }
}

import AppKit
import SwiftUI

@main
struct INDIMCPKitTestAppApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

/// Run via `swift run INDIMCPKitTestApp` rather than as a proper `.app` bundle from Xcode/Finder,
/// so nothing else makes it the frontmost app — without this, the window shows but never gets
/// keyboard focus, and text fields can't be typed into.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

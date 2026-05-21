import SwiftUI
import AppKit

@main
struct SwitcherooApp: App {
    init() {
        Self.terminateOtherInstances()
    }

    var body: some Scene {
        MenuBarExtra("Switcheroo", systemImage: "network") {
            HostsEditorView()
        }
        .menuBarExtraStyle(.window)
    }

    /// Kill any previously-running Switcheroo processes so there's only ever one
    /// menu-bar icon. Xcode launches from DerivedData bypass LaunchServices'
    /// normal single-instancing, so we enforce it manually.
    private static func terminateOtherInstances() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let me = NSRunningApplication.current
        let others = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != me.processIdentifier }
        for app in others {
            if !app.terminate() {
                app.forceTerminate()
            }
        }
    }
}

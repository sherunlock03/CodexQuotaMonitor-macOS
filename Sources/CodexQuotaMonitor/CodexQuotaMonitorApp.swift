import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var isDuplicateInstance = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return }
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let instances = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .sorted { $0.processIdentifier < $1.processIdentifier }

        guard let primary = instances.first,
              primary.processIdentifier != currentPID else { return }

        isDuplicateInstance = true
        primary.activate(options: [.activateAllWindows])
        DispatchQueue.main.async {
            NSApplication.shared.terminate(nil)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !isDuplicateInstance else { return }
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        if !flag {
            let dashboard = sender.windows.first { $0.title == "Codex 额度" }
                ?? sender.windows.first { $0.canBecomeKey }
            dashboard?.makeKeyAndOrderFront(nil)
        }
        sender.activate(ignoringOtherApps: true)
        return true
    }
}

@main
struct CodexQuotaMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = QuotaStore()

    var body: some Scene {
        Window("Codex 额度", id: "dashboard") {
            DashboardView(store: store)
        }
        .windowResizability(.contentSize)

        MenuBarExtra {
            DashboardView(store: store)
        } label: {
            Label(store.menuBarTitle, systemImage: "gauge.with.dots.needle.67percent")
        }
        .menuBarExtraStyle(.window)
    }
}

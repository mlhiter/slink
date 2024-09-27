import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var viewController: ViewController!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let windowRect = NSRect(x: 100, y: 100, width: 300, height: 200)
        window = NSWindow(contentRect: windowRect, styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Dock Icon Hider"

        viewController = ViewController()
        window.contentViewController = viewController
        window.makeKeyAndOrderFront(nil)
    }

    func getRunningApplications() -> [NSRunningApplication] {
        return NSWorkspace.shared.runningApplications
    }

    func toggleDockIcon(for app: NSRunningApplication) {
        guard let bundleIdentifier = app.bundleIdentifier else { return }

        if app.activationPolicy == .regular {
            hideDockIcon(for: bundleIdentifier)
        } else {
            showDockIcon(for: bundleIdentifier)
        }
    }

    func hideDockIcon(for bundleIdentifier: String) {
        let task = Process()
        task.launchPath = "/usr/bin/defaults"
        task.arguments = ["write", bundleIdentifier, "LSUIElement", "1"]
        task.launch()
        task.waitUntilExit()
    }

    func showDockIcon(for bundleIdentifier: String) {
        let task = Process()
        task.launchPath = "/usr/bin/defaults"
        task.arguments = ["delete", bundleIdentifier, "LSUIElement"]
        task.launch()
        task.waitUntilExit()
    }
}

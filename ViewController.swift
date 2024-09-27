import Cocoa

class ViewController: NSViewController {
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 200))

        let button = NSButton(frame: NSRect(x: 100, y: 100, width: 100, height: 30))
        button.title = "Toggle Dock Icon"
        button.bezelStyle = .rounded
        button.target = self
        button.action = #selector(toggleDockIconButtonClicked)

        self.view.addSubview(button)
    }

    @objc func toggleDockIconButtonClicked() {
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            let runningApps = appDelegate.getRunningApplications()
            // 这里我们只是选择第一个运行的应用作为示例
            if let firstApp = runningApps.first {
                appDelegate.toggleDockIcon(for: firstApp)
            }
        }
    }
}

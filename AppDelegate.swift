import Cocoa
import ServiceManagement

// @main  // 注释掉或删除这一行
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var viewController: ViewController!

    func requestAccessibilityPermissions() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)

        if !accessEnabled {
            print("请在系统偏好设置中授予此应用辅助功能权限。")
            // 打开系统偏好设置的辅助功能面板
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        } else {
            print("已获得辅助功能权限。")
        }
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // 创建窗口，增加大小
        window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 900, height: 600),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered,
                          defer: false)

        // 创建并设置 ViewController
        viewController = ViewController()
        window.contentViewController = viewController

        // 显示窗口
        window.makeKeyAndOrderFront(nil)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    func getRunningApplications() -> [NSRunningApplication] {
        return NSWorkspace.shared.runningApplications
    }

    func toggleDockIcon(for app: NSRunningApplication) {
        guard let bundleIdentifier = app.bundleIdentifier else { return }

        let script = """
        tell application id "\(bundleIdentifier)"
            set visible to not visible
        end tell
        """

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
            if let error = error {
                print("执行 AppleScript 时出错: \(error)")
            }
        }
    }

    func showDockIcon(for path: String) -> Bool {
        return modifyInfoPlist(for: path, setHidden: false)
    }

    func hideDockIcon(for path: String) -> Bool {
        return modifyInfoPlist(for: path, setHidden: true)
    }

    private func modifyInfoPlist(for path: String, setHidden: Bool) -> Bool {
        let fileManager = FileManager.default
        let infoPlistPath = (path as NSString).appendingPathComponent("Contents/Info.plist")

        guard fileManager.fileExists(atPath: infoPlistPath) else {
            print("Info.plist 文件不存在：\(infoPlistPath)")
            return false
        }

        guard var plistDict = NSDictionary(contentsOfFile: infoPlistPath) as? [String: Any] else {
            print("无法读取 Info.plist 文件")
            return false
        }

        if setHidden {
            plistDict["LSUIElement"] = "1"
        } else {
            plistDict.removeValue(forKey: "LSUIElement")
        }

        let plistData = try? PropertyListSerialization.data(fromPropertyList: plistDict, format: .xml, options: 0)

        do {
            try plistData?.write(to: URL(fileURLWithPath: infoPlistPath))
            print(setHidden ? "成功隐藏 Dock 图标" : "成功显示 Dock 图标")

            // 在成功修改 plist 后重启应用
            restartApplication(at: path)

            return true
        } catch {
            print("写入 Info.plist 失败：\(error)")
            return false
        }
    }

    func toggleLoginItemState() {
        let currentStatus = SMAppService.mainApp.status
        do {
            if currentStatus == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            print("登录项状态已成功切换")
        } catch {
            print("切换登录项状态失败: \(error)")
        }
    }

    func isLoginItemEnabled() -> Bool {
        return SMAppService.mainApp.status == .enabled
    }

    func getDockApplications() -> [(URL, String, Bool)] {
        var dockApps = getDockPlistApplications()
        let runningApps = getRunningApplications()

        for app in runningApps {
            if let bundleURL = app.bundleURL,
               let bundleName = app.localizedName,
               !dockApps.contains(where: { $0.0 == bundleURL }),
               app.activationPolicy != .prohibited {
                let isHidden = isDockIconHidden(for: bundleURL.path)
                dockApps.append((bundleURL, bundleName, isHidden))
            }
        }

        return dockApps
    }

    private func getDockPlistApplications() -> [(URL, String, Bool)] {
        let fileManager = FileManager.default
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        let dockPlistPath = homeDirectory.appendingPathComponent("Library/Preferences/com.apple.dock.plist")

        guard let plistData = try? Data(contentsOf: dockPlistPath),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any],
              let persistentApps = plist["persistent-apps"] as? [[String: Any]] else {
            return []
        }

        var dockApps: [(URL, String, Bool)] = []

        for app in persistentApps {
            if let tileData = app["tile-data"] as? [String: Any],
               let fileData = tileData["file-data"] as? [String: Any],
               let fileURLString = fileData["_CFURLString"] as? String,
               let url = URL(string: fileURLString),
               let label = tileData["file-label"] as? String {
                let isHidden = isDockIconHidden(for: url.path)
                dockApps.append((url, label, isHidden))
            }
        }

        return dockApps
    }

    private func restartApplication(at path: String) {
        let bundleURL = URL(fileURLWithPath: path)
        let bundleIdentifier = Bundle(url: bundleURL)?.bundleIdentifier

        // 尝试获取正在运行的应用程序
        guard let application = NSWorkspace.shared.runningApplications.first(where: { $0.bundleURL == bundleURL }) else {
            print("找不到正在运行的应用程序")
            return
        }

        // 强制终止应用程序
        application.forceTerminate()

        // 等待应用程序完全终止
        while application.isTerminated == false {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        }

        // 使用 NSWorkspace 重新启动应用程序
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let bundleIdentifier = bundleIdentifier {
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = true
                NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { (app, error) in
                    if let error = error {
                        print("重新启动应用程序时出错：\(error.localizedDescription)")
                    } else {
                        print("应用程序已成功重新启动")
                    }
                }
            } else {
                print("无法获取应用程序的 Bundle Identifier")
            }
        }
    }

    func isDockIconHidden(for path: String) -> Bool {
        let infoPlistPath = (path as NSString).appendingPathComponent("Contents/Info.plist")
        guard let plistDict = NSDictionary(contentsOfFile: infoPlistPath) as? [String: Any] else {
            return false
        }
        return plistDict["LSUIElement"] as? String == "1"
    }
}

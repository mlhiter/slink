import Cocoa

class ViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {

    var appTableView: NSTableView!
    var apps: [(URL, String, Bool)] = []
    var scrollView: NSScrollView!

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
        loadApps()
    }

    func setupTableView() {
        // 创建 NSScrollView
        scrollView = NSScrollView(frame: view.bounds)
        scrollView.hasVerticalScroller = true
        scrollView.autoresizingMask = [.width, .height]

        // 创建 NSTableView
        appTableView = NSTableView(frame: scrollView.bounds)
        appTableView.delegate = self
        appTableView.dataSource = self
        appTableView.autoresizingMask = [.width, .height]

        // 创建并添加列
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("AppColumn"))
        column.title = "应用"
        column.resizingMask = .autoresizingMask
        appTableView.addTableColumn(column)

        // 设置行高
        appTableView.rowHeight = 60

        // 设置 NSScrollView 的文档视图为 NSTableView
        scrollView.documentView = appTableView

        // 将 NSScrollView 添加到主视图
        view.addSubview(scrollView)

        // 设置约束
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        // 调整列宽度以适应视图宽度
        if let column = appTableView.tableColumns.first {
            column.width = scrollView.contentSize.width - scrollView.verticalScroller!.frame.width
        }
    }

    func loadApps() {
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            apps = appDelegate.getDockApplications()
            appTableView.reloadData()
        }
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        return apps.count
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cellIdentifier = NSUserInterfaceItemIdentifier("AppCell")

        var cell = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView
        if cell == nil {
            cell = NSTableCellView()

            // 创建应用图标
            let iconView = NSImageView()
            iconView.translatesAutoresizingMaskIntoConstraints = false
            cell?.addSubview(iconView)

            // 创建应用名称标签
            let textField = NSTextField()
            textField.isBordered = false
            textField.isEditable = false
            textField.drawsBackground = false
            textField.translatesAutoresizingMaskIntoConstraints = false
            cell?.textField = textField
            cell?.addSubview(textField)

            // 创建切换按钮
            let toggleButton = NSButton()
            toggleButton.bezelStyle = .rounded
            toggleButton.setButtonType(.momentaryPushIn)
            toggleButton.target = self
            toggleButton.action = #selector(toggleDockIcon(_:))
            toggleButton.translatesAutoresizingMaskIntoConstraints = false
            cell?.addSubview(toggleButton)

            // 设置约束
            NSLayoutConstraint.activate([
                iconView.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 10),
                iconView.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
                iconView.widthAnchor.constraint(equalToConstant: 30),
                iconView.heightAnchor.constraint(equalToConstant: 30),

                textField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
                textField.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
                textField.trailingAnchor.constraint(equalTo: toggleButton.leadingAnchor, constant: -10),

                toggleButton.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -10),
                toggleButton.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
                toggleButton.widthAnchor.constraint(equalToConstant: 70),
                toggleButton.heightAnchor.constraint(equalToConstant: 30)
            ])

            cell?.identifier = cellIdentifier
        }

        let (appURL, appName, isHidden) = apps[row]

        // 设置应用图标
        if let iconView = cell?.subviews[0] as? NSImageView {
            iconView.image = NSWorkspace.shared.icon(forFile: appURL.path)
        }

        // 设置应用名称
        cell?.textField?.stringValue = appName

        // 设置切换按钮状态和样式
        if let toggleButton = cell?.subviews[2] as? NSButton {
            updateButtonStyle(toggleButton, isHidden: isHidden)
            toggleButton.tag = row
        }

        return cell
    }

    private func updateButtonStyle(_ button: NSButton, isHidden: Bool) {
        button.title = isHidden ? "显示" : "隐藏"
        button.wantsLayer = true
        button.layer?.cornerRadius = 15  // 圆角半径为按钮高度的一半
        button.layer?.masksToBounds = true

        if isHidden {
            button.contentTintColor = .white
            button.layer?.backgroundColor = NSColor.systemBlue.cgColor
        } else {
            button.contentTintColor = .white
            button.layer?.backgroundColor = NSColor.systemGray.cgColor
        }

        // 调整字体大小
        button.font = NSFont.systemFont(ofSize: 13)

        // 移除默认的按钮样式
        button.isBordered = false
    }

    @IBAction func toggleDockIcon(_ sender: NSButton) {
        guard let appDelegate = NSApplication.shared.delegate as? AppDelegate else {
            print("无法获取 AppDelegate")
            return
        }

        let row = sender.tag
        let (appURL, appName, isCurrentlyHidden) = apps[row]

        print("切换应用：\(appName)，当前状态：\(isCurrentlyHidden ? "隐藏" : "显示")")

        if sender.state == .on {
            // 用户点击了"隐藏"
            if appDelegate.hideDockIcon(for: appURL.path) {
                print("\(appName) 的 Dock 图标已隐藏")
                apps[row].2 = true
                sender.title = "显示"
            } else {
                print("隐藏 \(appName) 的 Dock 图标失败")
                sender.state = .off
                sender.title = "隐藏"
            }
        } else {
            // 用户点击了"显示"
            if appDelegate.showDockIcon(for: appURL.path) {
                print("\(appName) 的 Dock 图标已显示")
                apps[row].2 = false
                sender.title = "隐藏"
            } else {
                print("显示 \(appName) 的 Dock 图标失败")
                sender.state = .on
                sender.title = "显示"
            }
        }

        appTableView.reloadData()
    }
}

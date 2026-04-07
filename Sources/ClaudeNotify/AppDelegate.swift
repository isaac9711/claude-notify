import Cocoa
import UserNotifications
import Sparkle
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var statusItem: NSStatusItem!
    private let history = NotificationHistory()
    private var updaterController: SPUStandardUpdaterController!

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Apply saved language to AppleLanguages for Sparkle localization
        let resolved = Language.current.rawValue
        UserDefaults.standard.set([resolved], forKey: "AppleLanguages")

        setupSparkle()
        setupLoginItem()
        setupMenuBar()
        setupNotificationCenter()
        setupIPCObserver()

        // Handle launch args if this is the first instance with notification args
        let args = ProcessInfo.processInfo.arguments
        if NotificationPayload.hasNotificationArgs(args) {
            let payload = NotificationPayload.fromArgs(args)
            sendNotification(payload)
        }
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "bell.fill", accessibilityDescription: "ClaudeNotify")
        }
        rebuildMenu()
    }

    func rebuildMenu() {
        let menu = NSMenu()

        // Recent notifications submenu
        let recentItem = NSMenuItem(title: L10n.get("recentNotifications"), action: nil, keyEquivalent: "")
        let recentMenu = NSMenu()
        if history.records.isEmpty {
            let emptyItem = NSMenuItem(title: L10n.get("noNotifications"), action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            recentMenu.addItem(emptyItem)
        } else {
            for (index, record) in history.records.enumerated() {
                let label = record.subtitle.isEmpty
                    ? record.payload.title
                    : "\(record.subtitle) — \(record.payload.title)"
                let truncated = label.count > 40 ? String(label.prefix(37)) + "..." : label
                let item = NSMenuItem(title: truncated, action: #selector(activateFromHistory(_:)), keyEquivalent: "")
                item.target = self
                item.tag = index
                if !record.payload.message.isEmpty {
                    item.toolTip = record.payload.message
                }
                recentMenu.addItem(item)
            }
            recentMenu.addItem(.separator())
            let clearItem = NSMenuItem(title: L10n.get("clearHistory"), action: #selector(clearHistory), keyEquivalent: "")
            clearItem.target = self
            recentMenu.addItem(clearItem)
        }
        recentItem.submenu = recentMenu
        menu.addItem(recentItem)

        menu.addItem(.separator())

        // Check for updates
        let updateItem = NSMenuItem(title: L10n.get("checkForUpdates"), action: #selector(checkForUpdatesManually(_:)), keyEquivalent: "")
        updateItem.target = self
        menu.addItem(updateItem)

        // Settings submenu
        let settingsItem = NSMenuItem(title: L10n.get("settings"), action: nil, keyEquivalent: "")
        let settingsMenu = NSMenu()

        let loginItem = NSMenuItem(title: L10n.get("launchAtLogin"), action: #selector(toggleLoginItem(_:)), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = UserDefaults.standard.bool(forKey: "launchAtLogin") ? .on : .off
        settingsMenu.addItem(loginItem)

        let autoUpdateItem = NSMenuItem(title: L10n.get("automaticUpdates"), action: #selector(toggleAutoUpdate(_:)), keyEquivalent: "")
        autoUpdateItem.target = self
        autoUpdateItem.state = updaterController?.updater.automaticallyChecksForUpdates == true ? .on : .off
        settingsMenu.addItem(autoUpdateItem)

        // Language submenu
        settingsMenu.addItem(.separator())
        let langItem = NSMenuItem(title: L10n.get("language"), action: nil, keyEquivalent: "")
        let langMenu = NSMenu()
        let currentSelection = Language.savedSelection
        for lang in Language.allCases {
            let item = NSMenuItem(title: lang.displayName, action: #selector(changeLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = lang.rawValue
            item.state = lang == currentSelection ? .on : .off
            langMenu.addItem(item)
        }
        langItem.submenu = langMenu
        settingsMenu.addItem(langItem)

        settingsItem.submenu = settingsMenu
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: L10n.get("quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: - Notification Sending

    func sendNotification(_ payload: NotificationPayload) {
        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.title = payload.title
        content.body = payload.message
        content.sound = payload.sound == "default"
            ? .default
            : UNNotificationSound(named: UNNotificationSoundName(rawValue: payload.sound))
        content.userInfo = payload.dictionary

        // Set subtitle and attach source app icon
        var subtitle = ""
        if !payload.activate.isEmpty,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: payload.activate) {
            let appName = appURL.deletingPathExtension().lastPathComponent
            subtitle = appName
            content.subtitle = appName

            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("claude-notify-icon-\(UUID().uuidString).png")
            if let tiffData = icon.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                try? pngData.write(to: tempURL)
                if let attachment = try? UNNotificationAttachment(identifier: "icon", url: tempURL, options: nil) {
                    content.attachments = [attachment]
                }
            }
        }

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(request) { error in
            if let error = error {
                fputs("Notification error: \(error.localizedDescription)\n", stderr)
            }
        }

        // Add to history and refresh menu
        history.add(payload: payload, subtitle: subtitle)
        rebuildMenu()
    }

    // MARK: - IPC Observer

    private func setupIPCObserver() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleIPCNotification(_:)),
            name: Notification.Name("com.claude.notify.send"),
            object: nil
        )
    }

    @objc private func handleIPCNotification(_ notification: Notification) {
        guard let jsonString = notification.object as? String,
              let payload = NotificationPayload.fromJSON(jsonString)
        else { return }
        DispatchQueue.main.async {
            self.sendNotification(payload)
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    private func setupNotificationCenter() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        let bundleId = userInfo["activate"] as? String ?? ""
        let workspace = userInfo["workspace"] as? String ?? ""
        let session = userInfo["session"] as? String ?? ""
        let windowIdStr = userInfo["windowId"] as? String ?? ""

        activateApp(bundleId: bundleId, workspace: workspace, session: session, windowIdStr: windowIdStr)
        completionHandler()
    }

    // MARK: - App Activation

    func activateApp(bundleId: String, workspace: String, session: String, windowIdStr: String) {
        guard !bundleId.isEmpty else { return }

        var windowID: CGWindowID = 0
        var windowPID: pid_t = 0
        if !windowIdStr.isEmpty {
            let parts = windowIdStr.split(separator: ":")
            if parts.count == 2, let wid = UInt32(parts[0]), let pid = Int32(parts[1]) {
                windowID = CGWindowID(wid)
                windowPID = pid
            }
        }

        if !session.isEmpty && session.hasPrefix("/dev/") {
            // macOS Terminal: Space switch + select tab by tty
            if windowID != 0 { activateWindow(windowID: windowID, pid: windowPID); usleep(200000) }
            let script = """
            tell application "Terminal"
                repeat with w in windows
                    repeat with t in tabs of w
                        if tty of t is "\(session)" then
                            set selected of t to true
                            set index of w to 1
                            return
                        end if
                    end repeat
                end repeat
            end tell
            """
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            task.arguments = ["-e", script]
            try? task.run()
            task.waitUntilExit()
        } else if !session.isEmpty && session.contains(":") && !session.hasPrefix("/") {
            // iTerm: Space switch + select tab by session GUID
            if windowID != 0 { activateWindow(windowID: windowID, pid: windowPID); usleep(200000) }
            let guid = String(session.split(separator: ":").last ?? "")
            let script = """
            tell application "iTerm2"
                repeat with w in windows
                    repeat with t in tabs of w
                        repeat with s in sessions of t
                            if unique ID of s is "\(guid)" then
                                select w
                                tell w to select t
                                return
                            end if
                        end repeat
                    end repeat
                end repeat
            end tell
            """
            var errorInfo: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&errorInfo)
        } else if session == "activate-only" {
            // Warp: just activate app
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            task.arguments = ["-b", bundleId]
            try? task.run()
            task.waitUntilExit()
        } else if !workspace.isEmpty {
            // Cursor/VS Code: open workspace path
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            task.arguments = ["-b", bundleId, workspace]
            try? task.run()
            task.waitUntilExit()
        } else {
            // Others: just activate app
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            task.arguments = ["-b", bundleId]
            try? task.run()
            task.waitUntilExit()
        }
    }

    // MARK: - Sparkle

    @objc func checkForUpdatesManually(_ sender: Any?) {
        guard let feedURL = updaterController.updater.feedURL else { return }

        let task = URLSession.shared.dataTask(with: feedURL) { [weak self] data, response, error in
            DispatchQueue.main.async {
                let httpResponse = response as? HTTPURLResponse
                if httpResponse?.statusCode == 200, error == nil {
                    self?.updaterController.checkForUpdates(sender)
                } else {
                    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
                    let alert = NSAlert()
                    alert.messageText = L10n.get("noUpdatesTitle")
                    alert.informativeText = L10n.get("noUpdatesMessage").replacingOccurrences(of: "{version}", with: version)
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
        task.resume()
    }

    private func setupSparkle() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        do {
            try updaterController.updater.start()
        } catch {
            fputs("Sparkle start error: \(error)\n", stderr)
        }
    }

    // MARK: - Login Item

    private func setupLoginItem() {
        if !UserDefaults.standard.bool(forKey: "loginItemConfigured") {
            UserDefaults.standard.set(true, forKey: "launchAtLogin")
            UserDefaults.standard.set(true, forKey: "loginItemConfigured")
            try? SMAppService.mainApp.register()
        }
    }

    @objc private func toggleLoginItem(_ sender: NSMenuItem) {
        let enable = sender.state == .off
        UserDefaults.standard.set(enable, forKey: "launchAtLogin")
        if enable {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
        rebuildMenu()
    }

    @objc private func toggleAutoUpdate(_ sender: NSMenuItem) {
        updaterController.updater.automaticallyChecksForUpdates.toggle()
        rebuildMenu()
    }

    @objc private func changeLanguage(_ sender: NSMenuItem) {
        guard let langCode = sender.representedObject as? String else { return }
        UserDefaults.standard.set(langCode, forKey: "language")
        // Set AppleLanguages so Sparkle picks up the language override
        let resolved = Language.current.rawValue
        UserDefaults.standard.set([resolved], forKey: "AppleLanguages")
        rebuildMenu()
    }

    // MARK: - History Actions

    @objc private func clearHistory() {
        history.clear()
        rebuildMenu()
    }

    @objc private func activateFromHistory(_ sender: NSMenuItem) {
        let index = sender.tag
        guard index < history.records.count else { return }
        let record = history.records[index]
        let p = record.payload
        activateApp(bundleId: p.activate, workspace: p.workspace, session: p.session, windowIdStr: p.windowId)
    }
}

import Cocoa
import UserNotifications
import Sparkle
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var statusItem: NSStatusItem!
    private let history = NotificationHistory()
    private var updaterController: SPUStandardUpdaterController!
    private var iconPNGCache: [String: Data] = [:]

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

        // First launch: prompt to select settings.json and install hooks
        // Or: after update, check if hooks need updating
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.checkHookSetup()
        }
    }

    private func checkHookSetup() {
        let hook = HookManager.shared

        if !hook.isConfigured {
            // First launch — ask to install hooks
            let alert = NSAlert()
            alert.messageText = "ClaudeNotify"
            alert.informativeText = L10n.get("setupHooksPrompt")
            alert.alertStyle = .informational
            alert.addButton(withTitle: L10n.get("install"))
            alert.addButton(withTitle: L10n.get("skip"))
            if alert.runModal() == .alertFirstButtonReturn {
                if hook.selectSettingsFile() {
                    if let preview = hook.previewInstall() {
                        guard DiffPreview.showConfirmation(
                            title: L10n.get("installHooks"),
                            oldJSON: preview.old,
                            newJSON: preview.new
                        ) else { rebuildMenu(); return }
                    }
                    let result = hook.installHooks()
                    showHookResult(result.message)
                }
            }
        } else if hook.needsHookUpdate {
            // App updated, hooks need refresh
            if let preview = hook.previewInstall() {
                guard DiffPreview.showConfirmation(
                    title: L10n.get("hookUpdateAvailable"),
                    oldJSON: preview.old,
                    newJSON: preview.new
                ) else { rebuildMenu(); return }
            }
            let result = hook.installHooks(force: true)
            showHookResult(result.message)
        } else if hook.isConfigured && !hook.hasHooksInstalled() {
            // Settings path configured but hooks missing (removed externally)
            let alert = NSAlert()
            alert.messageText = "ClaudeNotify"
            alert.informativeText = L10n.get("hooksMissing")
            alert.alertStyle = .warning
            alert.addButton(withTitle: L10n.get("install"))
            alert.addButton(withTitle: L10n.get("skip"))
            if alert.runModal() == .alertFirstButtonReturn {
                if let preview = hook.previewInstall() {
                    guard DiffPreview.showConfirmation(
                        title: L10n.get("installHooks"),
                        oldJSON: preview.old,
                        newJSON: preview.new
                    ) else { rebuildMenu(); return }
                }
                let result = hook.installHooks()
                showHookResult(result.message)
            }
        }
        rebuildMenu()
    }

    private func showHookResult(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "ClaudeNotify"
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
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

        // Hooks submenu
        settingsMenu.addItem(.separator())
        let hookItem = NSMenuItem(title: L10n.get("hooks"), action: nil, keyEquivalent: "")
        let hookMenu = NSMenu()
        let hook = HookManager.shared
        if hook.hasHooksInstalled() {
            let uninstallItem = NSMenuItem(title: L10n.get("uninstallHooks"), action: #selector(uninstallHooksAction), keyEquivalent: "")
            uninstallItem.target = self
            hookMenu.addItem(uninstallItem)
        } else {
            let installItem = NSMenuItem(title: L10n.get("installHooks"), action: #selector(installHooksAction), keyEquivalent: "")
            installItem.target = self
            hookMenu.addItem(installItem)
        }
        hookMenu.addItem(.separator())
        let wsLabel = NSMenuItem(title: L10n.get("workspaceMode"), action: nil, keyEquivalent: "")
        wsLabel.isEnabled = false
        hookMenu.addItem(wsLabel)

        let baseItem = NSMenuItem(title: L10n.get("workspaceBase"), action: #selector(setWorkspaceBase), keyEquivalent: "")
        baseItem.target = self
        baseItem.state = hook.workspaceMode == "base" ? .on : .off
        hookMenu.addItem(baseItem)

        let worktreeItem = NSMenuItem(title: L10n.get("workspaceWorktree"), action: #selector(setWorkspaceWorktree), keyEquivalent: "")
        worktreeItem.target = self
        worktreeItem.state = hook.workspaceMode == "worktree" ? .on : .off
        hookMenu.addItem(worktreeItem)

        hookMenu.addItem(.separator())
        let changePathItem = NSMenuItem(title: L10n.get("changeSettingsPath"), action: #selector(changeSettingsPathAction), keyEquivalent: "")
        changePathItem.target = self
        hookMenu.addItem(changePathItem)
        hookItem.submenu = hookMenu
        settingsMenu.addItem(hookItem)

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
        // Skip if target app is already in foreground (user is already looking at it)
        if !payload.activate.isEmpty,
           let app = NSRunningApplication.runningApplications(withBundleIdentifier: payload.activate).first,
           app.isActive {
            return
        }

        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.title = payload.title
        content.body = payload.message
        content.sound = payload.sound == "default"
            ? .default
            : UNNotificationSound(named: UNNotificationSoundName(rawValue: payload.sound))
        content.userInfo = payload.dictionary

        // Set subtitle and attach source app icon (cached)
        var subtitle = ""
        if !payload.activate.isEmpty,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: payload.activate) {
            let appName = appURL.deletingPathExtension().lastPathComponent
            subtitle = appName
            content.subtitle = appName

            // Cache icon PNG data per bundleId
            let pngData: Data? = iconPNGCache[payload.activate] ?? {
                guard let icon = NSWorkspace.shared.icon(forFile: appURL.path).tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: icon),
                      let data = bitmap.representation(using: .png, properties: [:])
                else { return nil }
                iconPNGCache[payload.activate] = data
                return data
            }()

            if let pngData = pngData {
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("claude-notify-icon-\(payload.activate).png")
                try? pngData.write(to: tempURL)
                if let attachment = try? UNNotificationAttachment(identifier: "icon", url: tempURL, options: nil) {
                    content.attachments = [attachment]
                }
            }
        }

        // Use session as identifier — same session replaces previous notification
        let notifId = payload.session.isEmpty ? UUID().uuidString : payload.session
        let request = UNNotificationRequest(identifier: notifId, content: content, trigger: nil)
        center.add(request) { error in
            if let error = error {
                fputs("Notification error: \(error.localizedDescription)\n", stderr)
            }
        }

        // Add to history and refresh menu async
        history.add(payload: payload, subtitle: subtitle)
        DispatchQueue.main.async { self.rebuildMenu() }
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

        // Deactivate ClaudeNotify so target app gets focus
        NSApp.hide(nil)
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
            // iTerm: find correct window by GUID → Space switch → select tab
            let guid = String(session.split(separator: ":").last ?? "")

            // Step 1: AppleScript to get the window name containing the session
            let findScript = """
            tell application "iTerm2"
                repeat with w in windows
                    repeat with t in tabs of w
                        repeat with s in sessions of t
                            if unique ID of s is "\(guid)" then
                                return name of w
                            end if
                        end repeat
                    end repeat
                end repeat
            end tell
            """
            var findError: NSDictionary?
            let findResult = NSAppleScript(source: findScript)?.executeAndReturnError(&findError)
            let targetName = findResult?.stringValue ?? ""

            // Step 2: Find correct CGWindowID via AX API (works without Screen Recording permission)
            var activated = false
            if !targetName.isEmpty,
               let itermApp = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first {
                let pid = itermApp.processIdentifier
                let axApp = AXUIElementCreateApplication(pid)
                var windowsRef: CFTypeRef?
                AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef)
                if let windows = windowsRef as? [AXUIElement] {
                    for window in windows {
                        var titleRef: CFTypeRef?
                        AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)
                        let title = titleRef as? String ?? ""
                        if title == targetName {
                            var wid: CGWindowID = 0
                            if _AXUIElementGetWindow(window, &wid) == .success, wid != 0 {
                                activateWindow(windowID: wid, pid: pid)
                                usleep(200000)
                                activated = true
                                break
                            }
                        }
                    }
                }
            }
            if !activated && windowID != 0 {
                // Fallback to captured windowID
                activateWindow(windowID: windowID, pid: windowPID)
                usleep(200000)
            }

            // Step 3: AppleScript to select the correct tab
            let selectScript = """
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
            var selectError: NSDictionary?
            NSAppleScript(source: selectScript)?.executeAndReturnError(&selectError)
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

    // MARK: - Hook Actions

    @objc private func installHooksAction() {
        let hook = HookManager.shared
        if !hook.isConfigured {
            guard hook.selectSettingsFile() else { return }
        }
        if let preview = hook.previewInstall() {
            guard DiffPreview.showConfirmation(
                title: L10n.get("installHooks"),
                oldJSON: preview.old,
                newJSON: preview.new
            ) else { return }
        }
        let result = hook.installHooks()
        showHookResult(result.message)
        rebuildMenu()
    }

    @objc private func uninstallHooksAction() {
        let hook = HookManager.shared
        if let preview = hook.previewUninstall() {
            guard DiffPreview.showConfirmation(
                title: L10n.get("uninstallHooks"),
                oldJSON: preview.old,
                newJSON: preview.new
            ) else { return }
        }
        let result = hook.uninstallHooks()
        showHookResult(result.message)
        rebuildMenu()
    }

    @objc private func setWorkspaceBase() { changeWorkspaceMode("base") }
    @objc private func setWorkspaceWorktree() { changeWorkspaceMode("worktree") }

    private func changeWorkspaceMode(_ mode: String) {
        let hook = HookManager.shared
        hook.workspaceMode = mode
        if hook.hasHooksInstalled() {
            // Reinstall hooks with new workspace mode
            if let preview = hook.previewInstall() {
                guard DiffPreview.showConfirmation(
                    title: L10n.get("workspaceMode"),
                    oldJSON: preview.old,
                    newJSON: preview.new
                ) else {
                    // Revert mode if user cancels
                    hook.workspaceMode = mode == "base" ? "worktree" : "base"
                    rebuildMenu()
                    return
                }
            }
            let result = hook.installHooks(force: true)
            showHookResult(result.message)
        }
        rebuildMenu()
    }

    @objc private func changeSettingsPathAction() {
        let hook = HookManager.shared
        let hadHooks = hook.hasHooksInstalled()
        guard hook.selectSettingsFile() else { return }
        if hadHooks {
            let result = hook.installHooks(force: true)
            showHookResult(result.message)
        }
        rebuildMenu()
    }

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

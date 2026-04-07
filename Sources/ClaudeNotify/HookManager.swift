import Cocoa

class HookManager {
    static let shared = HookManager()

    // Bump this when hook commands change
    static let hookVersion = "2.0.0"

    var settingsPath: String? {
        get { UserDefaults.standard.string(forKey: "settingsJsonPath") }
        set { UserDefaults.standard.set(newValue, forKey: "settingsJsonPath") }
    }

    var installedHookVersion: String? {
        get { UserDefaults.standard.string(forKey: "installedHookVersion") }
        set { UserDefaults.standard.set(newValue, forKey: "installedHookVersion") }
    }

    var isConfigured: Bool { settingsPath != nil }

    var needsHookUpdate: Bool {
        guard isConfigured, hasHooksInstalled() else { return false }
        return installedHookVersion != HookManager.hookVersion
    }

    // MARK: - File Picker

    func selectSettingsFile(prompt: String? = nil) -> Bool {
        let panel = NSOpenPanel()
        panel.title = prompt ?? L10n.get("selectSettingsFile")
        panel.message = prompt ?? L10n.get("selectSettingsFile")
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.nameFieldStringValue = "settings.json"

        // Start in ~/.claude/ if it exists
        let defaultDir = NSString("~/.claude").expandingTildeInPath
        if FileManager.default.fileExists(atPath: defaultDir) {
            panel.directoryURL = URL(fileURLWithPath: defaultDir)
        }

        guard panel.runModal() == .OK, let url = panel.url else { return false }
        settingsPath = url.path
        return true
    }

    // MARK: - Hook Installation

    func installHooks() -> (success: Bool, message: String) {
        guard let path = settingsPath else { return (false, L10n.get("hookError")) }

        var settings = readSettings(at: path)

        // Check if already installed
        if let hooks = settings["hooks"] as? [String: Any],
           let notification = hooks["Notification"] as? [[String: Any]],
           notification.contains(where: { entry in
               if let innerHooks = entry["hooks"] as? [[String: Any]] {
                   return innerHooks.contains { ($0["command"] as? String)?.contains("ClaudeNotify") == true }
               }
               return false
           }) {
            return (true, L10n.get("hooksAlreadyInstalled"))
        }

        let notificationCommand = "N=/Applications/ClaudeNotify.app; S=; if [ \"$__CFBundleIdentifier\" = \"com.googlecode.iterm2\" ]; then S=\"$ITERM_SESSION_ID\"; elif [ \"$__CFBundleIdentifier\" = \"com.apple.Terminal\" ]; then S=\"/dev/$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')\"; elif [ \"$__CFBundleIdentifier\" = \"dev.warp.Warp-Stable\" ]; then S=\"activate-only\"; fi; W=$($N/Contents/MacOS/ClaudeNotify --get-window-id \"$__CFBundleIdentifier\" 2>/dev/null); open $N --args -title 'Claude Code' -message \"Waiting for input — $(basename \"$PWD\")\" -sound default -activate \"$__CFBundleIdentifier\" -workspace \"$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | xargs dirname 2>/dev/null || echo $PWD)\" -session \"$S\" -windowId \"$W\""

        let stopCommand = "N=/Applications/ClaudeNotify.app; S=; if [ \"$__CFBundleIdentifier\" = \"com.googlecode.iterm2\" ]; then S=\"$ITERM_SESSION_ID\"; elif [ \"$__CFBundleIdentifier\" = \"com.apple.Terminal\" ]; then S=\"/dev/$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')\"; elif [ \"$__CFBundleIdentifier\" = \"dev.warp.Warp-Stable\" ]; then S=\"activate-only\"; fi; W=$($N/Contents/MacOS/ClaudeNotify --get-window-id \"$__CFBundleIdentifier\" 2>/dev/null); open $N --args -title 'Claude Code' -message \"Task complete — $(basename \"$PWD\")\" -sound default -activate \"$__CFBundleIdentifier\" -workspace \"$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | xargs dirname 2>/dev/null || echo $PWD)\" -session \"$S\" -windowId \"$W\""

        var hooks = settings["hooks"] as? [String: Any] ?? [:]

        hooks["Notification"] = [[
            "matcher": "",
            "hooks": [["type": "command", "command": notificationCommand]]
        ]]

        hooks["Stop"] = [[
            "hooks": [["type": "command", "command": stopCommand]]
        ]]

        settings["hooks"] = hooks

        if writeSettings(settings, to: path) {
            installedHookVersion = HookManager.hookVersion
            return (true, L10n.get("hooksInstalled"))
        }
        return (false, L10n.get("hookError"))
    }

    func uninstallHooks() -> (success: Bool, message: String) {
        guard let path = settingsPath else { return (false, L10n.get("hookError")) }

        var settings = readSettings(at: path)
        guard var hooks = settings["hooks"] as? [String: Any] else {
            return (true, L10n.get("hooksUninstalled"))
        }

        // Remove only ClaudeNotify hooks
        for key in ["Notification", "Stop"] {
            if var entries = hooks[key] as? [[String: Any]] {
                entries.removeAll { entry in
                    if let innerHooks = entry["hooks"] as? [[String: Any]] {
                        return innerHooks.contains { ($0["command"] as? String)?.contains("ClaudeNotify") == true }
                    }
                    return false
                }
                if entries.isEmpty {
                    hooks.removeValue(forKey: key)
                } else {
                    hooks[key] = entries
                }
            }
        }

        if hooks.isEmpty {
            settings.removeValue(forKey: "hooks")
        } else {
            settings["hooks"] = hooks
        }

        if writeSettings(settings, to: path) {
            installedHookVersion = nil
            return (true, L10n.get("hooksUninstalled"))
        }
        return (false, L10n.get("hookError"))
    }

    func hasHooksInstalled() -> Bool {
        guard let path = settingsPath else { return false }
        let settings = readSettings(at: path)
        guard let hooks = settings["hooks"] as? [String: Any],
              let notification = hooks["Notification"] as? [[String: Any]] else { return false }
        return notification.contains { entry in
            if let innerHooks = entry["hooks"] as? [[String: Any]] {
                return innerHooks.contains { ($0["command"] as? String)?.contains("ClaudeNotify") == true }
            }
            return false
        }
    }

    // MARK: - JSON Read/Write

    private func readSettings(at path: String) -> [String: Any] {
        guard let data = FileManager.default.contents(atPath: path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        return json
    }

    private func writeSettings(_ settings: [String: Any], to path: String) -> Bool {
        guard let data = try? JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys]) else { return false }
        // Ensure parent directory exists
        let dir = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return FileManager.default.createFile(atPath: path, contents: data)
    }
}

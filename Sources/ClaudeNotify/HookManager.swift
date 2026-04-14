import Cocoa

class HookManager {
    static let shared = HookManager()

    // Bump this when hook commands change
    static let hookVersion = "3.0.0"

    var settingsPath: String? {
        get { UserDefaults.standard.string(forKey: "settingsJsonPath") }
        set { UserDefaults.standard.set(newValue, forKey: "settingsJsonPath") }
    }

    var installedHookVersion: String? {
        get { UserDefaults.standard.string(forKey: "installedHookVersion") }
        set { UserDefaults.standard.set(newValue, forKey: "installedHookVersion") }
    }

    var workspaceMode: String {
        get { UserDefaults.standard.string(forKey: "workspaceMode") ?? "base" }
        set { UserDefaults.standard.set(newValue, forKey: "workspaceMode") }
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

    func installHooks(force: Bool = false) -> (success: Bool, message: String) {
        guard let path = settingsPath else { return (false, L10n.get("hookError")) }

        var settings = readSettings(at: path)

        // Check if already installed (skip check when force updating)
        if !force, hasHooksInstalled(in: settings) {
            return (true, L10n.get("hooksAlreadyInstalled"))
        }

        // Remove existing ClaudeNotify hooks before (re)installing
        if var hooks = settings["hooks"] as? [String: Any] {
            for key in ["Notification", "Stop"] {
                if var entries = hooks[key] as? [[String: Any]] {
                    entries.removeAll { entry in
                        if let innerHooks = entry["hooks"] as? [[String: Any]] {
                            return innerHooks.contains { ($0["command"] as? String)?.contains("ClaudeNotify") == true }
                        }
                        return false
                    }
                    if entries.isEmpty { hooks.removeValue(forKey: key) } else { hooks[key] = entries }
                }
            }
            settings["hooks"] = hooks
        }

        var hooks = settings["hooks"] as? [String: Any] ?? [:]

        hooks["Notification"] = [buildNotificationHookEntry()]
        hooks["Stop"] = [buildStopHookEntry()]

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
        return hasHooksInstalled(in: settings)
    }

    private func hasHooksInstalled(in settings: [String: Any]) -> Bool {
        guard let hooks = settings["hooks"] as? [String: Any],
              let notification = hooks["Notification"] as? [[String: Any]] else { return false }
        return notification.contains { entry in
            if let innerHooks = entry["hooks"] as? [[String: Any]] {
                return innerHooks.contains { ($0["command"] as? String)?.contains("ClaudeNotify") == true }
            }
            return false
        }
    }

    // MARK: - Diff Preview

    func previewInstall() -> (old: String, new: String)? {
        guard let path = settingsPath else { return nil }
        let oldSettings = readSettings(at: path)
        let oldJSON = prettyJSON(oldSettings)

        var newSettings = oldSettings
        var hooks = newSettings["hooks"] as? [String: Any] ?? [:]
        hooks["Notification"] = [buildNotificationHookEntry()]
        hooks["Stop"] = [buildStopHookEntry()]
        newSettings["hooks"] = hooks
        let newJSON = prettyJSON(newSettings)

        return (oldJSON, newJSON)
    }

    func previewUninstall() -> (old: String, new: String)? {
        guard let path = settingsPath else { return nil }
        let oldSettings = readSettings(at: path)
        let oldJSON = prettyJSON(oldSettings)

        var newSettings = oldSettings
        if var hooks = newSettings["hooks"] as? [String: Any] {
            for key in ["Notification", "Stop"] {
                if var entries = hooks[key] as? [[String: Any]] {
                    entries.removeAll { entry in
                        if let innerHooks = entry["hooks"] as? [[String: Any]] {
                            return innerHooks.contains { ($0["command"] as? String)?.contains("ClaudeNotify") == true }
                        }
                        return false
                    }
                    if entries.isEmpty { hooks.removeValue(forKey: key) } else { hooks[key] = entries }
                }
            }
            if hooks.isEmpty { newSettings.removeValue(forKey: "hooks") } else { newSettings["hooks"] = hooks }
        }
        let newJSON = prettyJSON(newSettings)

        return (oldJSON, newJSON)
    }

    private func prettyJSON(_ dict: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: data, encoding: .utf8)
        else { return "{}" }
        return str
    }

    // MARK: - Hook Entries

    private func buildNotificationHookEntry() -> [String: Any] {
        ["matcher": "", "hooks": [["type": "command", "command": notificationCommand]]]
    }

    private func buildStopHookEntry() -> [String: Any] {
        ["hooks": [["type": "command", "command": stopCommand]]]
    }

    private var workspacePart: String {
        if workspaceMode == "worktree" {
            return "$(git rev-parse --show-toplevel 2>/dev/null || echo $PWD)"
        }
        return "$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | xargs dirname 2>/dev/null || echo $PWD)"
    }

    private var notificationCommand: String {
        "N=/Applications/ClaudeNotify.app/Contents/MacOS/ClaudeNotifySend; S=; if [ \"$__CFBundleIdentifier\" = \"com.googlecode.iterm2\" ]; then S=\"$ITERM_SESSION_ID\"; elif [ \"$__CFBundleIdentifier\" = \"com.apple.Terminal\" ]; then S=\"/dev/$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')\"; elif [ \"$__CFBundleIdentifier\" = \"dev.warp.Warp-Stable\" ]; then S=\"activate-only\"; fi; cat | $N --from-hook -activate \"$__CFBundleIdentifier\" -workspace \"\(workspacePart)\" -session \"$S\""
    }

    private var stopCommand: String {
        "N=/Applications/ClaudeNotify.app/Contents/MacOS/ClaudeNotifySend; S=; if [ \"$__CFBundleIdentifier\" = \"com.googlecode.iterm2\" ]; then S=\"$ITERM_SESSION_ID\"; elif [ \"$__CFBundleIdentifier\" = \"com.apple.Terminal\" ]; then S=\"/dev/$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')\"; elif [ \"$__CFBundleIdentifier\" = \"dev.warp.Warp-Stable\" ]; then S=\"activate-only\"; fi; cat | $N --from-hook -activate \"$__CFBundleIdentifier\" -workspace \"\(workspacePart)\" -session \"$S\""
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

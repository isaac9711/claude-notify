import Cocoa
import UserNotifications
import ApplicationServices

func getFrontWindowTitle(bundleId: String) -> String {
    guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first else { return "" }
    let axApp = AXUIElementCreateApplication(app.processIdentifier)

    var focusedWindow: CFTypeRef?
    AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &focusedWindow)

    if let window = focusedWindow {
        var titleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &titleRef)
        if let title = titleRef as? String { return title }
    }
    return ""
}

// Raise terminal mode: activate Terminal and select tab by tty
if CommandLine.arguments.contains("--raise-terminal") {
    if let idx = CommandLine.arguments.firstIndex(of: "--raise-terminal"),
       idx + 1 < CommandLine.arguments.count {
        let ttyPath = CommandLine.arguments[idx + 1]
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let script = """
            tell application "Terminal"
                activate
                repeat with w in windows
                    repeat with t in tabs of w
                        if tty of t is "\(ttyPath)" then
                            set selected of t to true
                            set index of w to 1
                            return
                        end if
                    end repeat
                end repeat
            end tell
            """
            var errorInfo: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&errorInfo)
            NSApp.terminate(nil)
        }
        app.run()
    }
    exit(0)
}

// Setup mode: request automation permissions (must run via `open` command)
if CommandLine.arguments.contains("--setup-terminal") {
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        let script = "tell application \"Terminal\" to get name of front window"
        var errorInfo: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&errorInfo)
        if let err = errorInfo {
            fputs("Error: \(err)\n", stderr)
        } else {
            fputs("Terminal automation permission granted.\n", stderr)
        }
        NSApp.terminate(nil)
    }
    app.run()
    exit(0)
}

// Quick-query mode: output window title and exit without starting GUI
if CommandLine.arguments.contains("--get-window-title") {
    if let idx = CommandLine.arguments.firstIndex(of: "--get-window-title"),
       idx + 1 < CommandLine.arguments.count {
        print(getFrontWindowTitle(bundleId: CommandLine.arguments[idx + 1]))
    }
    exit(0)
}

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var activateBundleId = ""

    func applicationDidFinishLaunching(_ notification: Notification) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        let args = ProcessInfo.processInfo.arguments
        guard args.count > 1 else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { NSApp.terminate(nil) }
            return
        }

        var title = "Claude Code"
        var message = ""
        var sound = "default"
        var workspace = ""
        var session = ""

        var i = 1
        while i < args.count {
            switch args[i] {
            case "-title":     i += 1; if i < args.count { title = args[i] }
            case "-message":   i += 1; if i < args.count { message = args[i] }
            case "-sound":     i += 1; if i < args.count { sound = args[i] }
            case "-activate":  i += 1; if i < args.count { activateBundleId = args[i] }
            case "-workspace": i += 1; if i < args.count { workspace = args[i] }
            case "-session":   i += 1; if i < args.count { session = args[i] }
            default: break
            }
            i += 1
        }

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            guard granted else {
                fputs("Permission denied\n", stderr)
                DispatchQueue.main.async { NSApp.terminate(nil) }
                return
            }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = message
            content.sound = sound == "default" ? .default : UNNotificationSound(named: UNNotificationSoundName(rawValue: sound))
            content.userInfo = [
                "activateBundle": self.activateBundleId,
                "workspace": workspace,
                "session": session
            ]

            // Set subtitle to source app name
            if !self.activateBundleId.isEmpty,
               let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: self.activateBundleId) {
                let appName = appURL.deletingPathExtension().lastPathComponent
                content.subtitle = appName

                // Attach source app icon
                let icon = NSWorkspace.shared.icon(forFile: appURL.path)
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("claude-notify-icon-\(UUID().uuidString).png")
                if let tiffData = icon.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmap.representation(using: .png, properties: [:]) {
                    try? pngData.write(to: tempURL)
                    if let attachment = try? UNNotificationAttachment(identifier: "icon", url: tempURL, options: nil) {
                        content.attachments = [attachment]
                    }
                }
            }

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )

            center.add(request) { error in
                if let error = error {
                    fputs("Error: \(error.localizedDescription)\n", stderr)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    NSApp.terminate(nil)
                }
            }
        }
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
        let bundleId = userInfo["activateBundle"] as? String ?? ""
        let workspace = userInfo["workspace"] as? String ?? ""
        let session = userInfo["session"] as? String ?? ""

        if !bundleId.isEmpty {
            if !session.isEmpty && session.hasPrefix("/dev/") {
                // macOS Terminal: use osascript process to find and select tab by tty
                let script = """
                tell application "Terminal"
                    activate
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
            } else if !session.isEmpty && session.contains(":") {
                // iTerm: find session by GUID
                let guid = String(session.split(separator: ":").last ?? "")
                let script = """
                tell application "iTerm2"
                    activate
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
                if errorInfo != nil {
                    let fallback = Process()
                    fallback.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                    fallback.arguments = ["-b", bundleId]
                    try? fallback.run()
                    fallback.waitUntilExit()
                }
            } else {
                // Other apps: open workspace path
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                if !workspace.isEmpty {
                    task.arguments = ["-b", bundleId, workspace]
                } else {
                    task.arguments = ["-b", bundleId]
                }
                try? task.run()
                task.waitUntilExit()
            }
        }
        completionHandler()
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let delegate = AppDelegate()
app.delegate = delegate
app.run()

import Cocoa
import UserNotifications
import ApplicationServices

// MARK: - Private API Declarations

// SkyLight/CGS private APIs for window activation with Space switching
@_silgen_name("_SLPSSetFrontProcessWithOptions")
@discardableResult
func _SLPSSetFrontProcessWithOptions(
    _ psn: UnsafeMutablePointer<ProcessSerialNumber>,
    _ wid: CGWindowID,
    _ mode: UInt32
) -> CGError

@_silgen_name("SLPSPostEventRecordTo")
@discardableResult
func SLPSPostEventRecordTo(
    _ psn: UnsafeMutablePointer<ProcessSerialNumber>,
    _ bytes: UnsafeMutablePointer<UInt8>
) -> CGError

@_silgen_name("GetProcessForPID")
@discardableResult
func GetProcessForPID(_ pid: pid_t, _ psn: UnsafeMutablePointer<ProcessSerialNumber>) -> OSStatus

// Get CGWindowID from AXUIElement
@_silgen_name("_AXUIElementGetWindow")
@discardableResult
func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: inout CGWindowID) -> AXError

// MARK: - Window Activation (handles fullscreen Space switching)

func activateWindow(windowID: CGWindowID, pid: pid_t) {
    var psn = ProcessSerialNumber()
    let psnResult = GetProcessForPID(pid, &psn)

    if psnResult == noErr {
        // Activate process targeting specific window — macOS auto-switches Space
        _SLPSSetFrontProcessWithOptions(&psn, windowID, 0x200)

        // Send synthetic key-window events
        var bytes = [UInt8](repeating: 0, count: 0xf8)
        bytes[0x04] = 0xf8
        bytes[0x3a] = 0x10
        var wid = windowID
        memcpy(&bytes[0x3c], &wid, MemoryLayout<UInt32>.size)
        memset(&bytes[0x20], 0xff, 0x10)

        bytes[0x08] = 0x01  // key down
        SLPSPostEventRecordTo(&psn, &bytes)
        bytes[0x08] = 0x02  // key up
        SLPSPostEventRecordTo(&psn, &bytes)
    }

}

// MARK: - Helper Functions

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

func getFrontWindowID(bundleId: String) -> (windowID: CGWindowID, pid: pid_t)? {
    guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first else { return nil }
    let pid = app.processIdentifier

    // Try AXUIElement first
    let axApp = AXUIElementCreateApplication(pid)
    var focusedWindow: CFTypeRef?
    AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &focusedWindow)

    if let window = focusedWindow {
        var windowID: CGWindowID = 0
        if _AXUIElementGetWindow(window as! AXUIElement, &windowID) == .success, windowID != 0 {
            return (windowID, pid)
        }
    }

    // Fallback: CGWindowList (for apps like Warp that don't expose AX window IDs)
    guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return nil }

    for window in windowList {
        if let ownerPID = window[kCGWindowOwnerPID as String] as? Int32,
           ownerPID == pid,
           let layer = window[kCGWindowLayer as String] as? Int, layer == 0,
           let windowNumber = window[kCGWindowNumber as String] as? CGWindowID {
            return (windowNumber, pid)
        }
    }
    return nil
}

// MARK: - CLI Modes

// Get focused window ID: outputs "windowID:pid"
if CommandLine.arguments.contains("--get-window-id") {
    if let idx = CommandLine.arguments.firstIndex(of: "--get-window-id"),
       idx + 1 < CommandLine.arguments.count {
        let bundleId = CommandLine.arguments[idx + 1]
        if let info = getFrontWindowID(bundleId: bundleId) {
            print("\(info.windowID):\(info.pid)")
        }
    }
    exit(0)
}

// Get focused window title
if CommandLine.arguments.contains("--get-window-title") {
    if let idx = CommandLine.arguments.firstIndex(of: "--get-window-title"),
       idx + 1 < CommandLine.arguments.count {
        print(getFrontWindowTitle(bundleId: CommandLine.arguments[idx + 1]))
    }
    exit(0)
}

// Raise terminal tab by tty
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

// Setup: request Terminal automation permission
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

// Setup: check accessibility permission
if CommandLine.arguments.contains("--setup") {
    let trusted = AXIsProcessTrustedWithOptions(
        [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
    )
    if !trusted {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        fputs("Accessibility permission required. Please add ClaudeNotify in the opened settings.\n", stderr)
    } else {
        fputs("Accessibility permission already granted.\n", stderr)
    }
    exit(0)
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var activateBundleId = ""

    func applicationDidFinishLaunching(_ notification: Notification) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        let args = ProcessInfo.processInfo.arguments
        guard args.count > 1 else {
            // No args: launched from notification click relaunch, just wait for didReceive
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { NSApp.terminate(nil) }
            return
        }

        var title = "Claude Code"
        var message = ""
        var sound = "default"
        var workspace = ""
        var session = ""
        var windowId = ""

        var i = 1
        while i < args.count {
            switch args[i] {
            case "-title":     i += 1; if i < args.count { title = args[i] }
            case "-message":   i += 1; if i < args.count { message = args[i] }
            case "-sound":     i += 1; if i < args.count { sound = args[i] }
            case "-activate":  i += 1; if i < args.count { activateBundleId = args[i] }
            case "-workspace": i += 1; if i < args.count { workspace = args[i] }
            case "-session":   i += 1; if i < args.count { session = args[i] }
            case "-windowId":  i += 1; if i < args.count { windowId = args[i] }
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
                "session": session,
                "windowId": windowId
            ]

            // Set subtitle to source app name + attach icon
            if !self.activateBundleId.isEmpty,
               let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: self.activateBundleId) {
                let appName = appURL.deletingPathExtension().lastPathComponent
                content.subtitle = appName

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
        let windowIdStr = userInfo["windowId"] as? String ?? ""

        if !bundleId.isEmpty {
            // Step 1: Try Space switching via private API (works for Cocoa native apps)
            if !windowIdStr.isEmpty {
                let parts = windowIdStr.split(separator: ":")
                if parts.count == 2,
                   let wid = UInt32(parts[0]),
                   let pid = Int32(parts[1]) {
                    activateWindow(windowID: CGWindowID(wid), pid: pid)
                    usleep(200000)
                }
            }

            // Step 2: App-specific activation (always runs)
            if !session.isEmpty && session.hasPrefix("/dev/") {
                // macOS Terminal: select tab by tty
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
                // iTerm: select tab by session GUID
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
                // Warp and other terminals without AppleScript: just activate app
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
        completionHandler()
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let delegate = AppDelegate()
app.delegate = delegate
app.run()

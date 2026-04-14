import Cocoa
import Foundation

let args = CommandLine.arguments

// MARK: - CLI Modes (immediate exit)

// Get focused window ID: outputs "windowID:pid"
if args.contains("--get-window-id") {
    if let idx = args.firstIndex(of: "--get-window-id"),
       idx + 1 < args.count {
        let bundleId = args[idx + 1]
        if let info = getFrontWindowID(bundleId: bundleId) {
            print("\(info.windowID):\(info.pid)")
        }
    }
    exit(0)
}

// Get focused window title
if args.contains("--get-window-title") {
    if let idx = args.firstIndex(of: "--get-window-title"),
       idx + 1 < args.count {
        print(getFrontWindowTitle(bundleId: args[idx + 1]))
    }
    exit(0)
}

// Raise terminal tab by tty
if args.contains("--raise-terminal") {
    if let idx = args.firstIndex(of: "--raise-terminal"),
       idx + 1 < args.count {
        let ttyPath = args[idx + 1]
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
if args.contains("--setup-terminal") {
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
if args.contains("--setup") {
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

// MARK: - Notification / Resident Mode

let hasNotifArgs = NotificationPayload.hasNotificationArgs(args)

// Check if another instance of ClaudeNotify is already running
let myPID = ProcessInfo.processInfo.processIdentifier
let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.claude.notify")
let alreadyRunning = runningApps.contains { $0.processIdentifier != myPID }

if alreadyRunning && hasNotifArgs {
    // Send notification to running instance via IPC
    // windowId is resolved at click time (AX API blocks on background apps)
    let payload = NotificationPayload.fromArgs(args)
    if let jsonString = payload.toJSON() {
        DistributedNotificationCenter.default().post(
            name: Notification.Name("com.claude.notify.send"),
            object: jsonString
        )
    }
    exit(0)
}

if alreadyRunning {
    // Already running, no notification to send — just exit
    exit(0)
}

// Launch as menu bar resident app
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()

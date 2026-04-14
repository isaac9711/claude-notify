import Foundation

// Lightweight IPC sender — no Sparkle, no Cocoa, minimal dyld load
// Posts notification payload to the resident ClaudeNotify app via DistributedNotificationCenter

let args = CommandLine.arguments

// Parse CLI args (activate, workspace, session — terminal-specific info)
var activate = ""
var workspace = ""
var session = ""
var cliTitle = ""
var cliMessage = ""
var cliSound = "default"
var windowId = ""
var fromHook = false

var i = 1
while i < args.count {
    switch args[i] {
    case "--from-hook": fromHook = true
    case "-title":     i += 1; if i < args.count { cliTitle = args[i] }
    case "-message":   i += 1; if i < args.count { cliMessage = args[i] }
    case "-sound":     i += 1; if i < args.count { cliSound = args[i] }
    case "-activate":  i += 1; if i < args.count { activate = args[i] }
    case "-workspace": i += 1; if i < args.count { workspace = args[i] }
    case "-session":   i += 1; if i < args.count { session = args[i] }
    case "-windowId":  i += 1; if i < args.count { windowId = args[i] }
    default: break
    }
    i += 1
}

var payload: [String: String] = [:]

if fromHook {
    // Read stdin JSON from Claude Code hook
    var stdinData = Data()
    while let byte = try? FileHandle.standardInput.availableData, !byte.isEmpty {
        stdinData.append(byte)
    }

    if let hookJSON = try? JSONSerialization.jsonObject(with: stdinData) as? [String: Any] {
        // Extract hook context
        let hookEvent = hookJSON["hook_event_name"] as? String ?? ""
        let permissionMode = hookJSON["permission_mode"] as? String ?? ""
        let notificationType = hookJSON["notification_type"] as? String ?? ""
        let stopReason = hookJSON["stop_reason"] as? String ?? ""
        let hookMessage = hookJSON["message"] as? String ?? ""
        let cwd = hookJSON["cwd"] as? String ?? ""

        payload["hookEvent"] = hookEvent
        payload["permissionMode"] = permissionMode
        payload["notificationType"] = notificationType
        payload["stopReason"] = stopReason
        payload["hookMessage"] = hookMessage
        if !cwd.isEmpty { payload["cwd"] = cwd }
    }
}

// CLI args override or supplement hook data
if !cliTitle.isEmpty { payload["title"] = cliTitle }
if !cliMessage.isEmpty { payload["message"] = cliMessage }
if payload["title"] == nil { payload["title"] = "Claude Code" }
if payload["sound"] == nil { payload["sound"] = cliSound }
payload["sound"] = cliSound
payload["activate"] = activate
payload["workspace"] = workspace
payload["session"] = session
if !windowId.isEmpty { payload["windowId"] = windowId }

if payload["message"]?.isEmpty != false && !fromHook { exit(0) }

guard let data = try? JSONSerialization.data(withJSONObject: payload),
      let jsonString = String(data: data, encoding: .utf8)
else { exit(1) }

DistributedNotificationCenter.default().post(
    name: Notification.Name("com.claude.notify.send"),
    object: jsonString
)

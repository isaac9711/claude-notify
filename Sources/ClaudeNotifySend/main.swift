import Foundation

// Lightweight IPC sender — no Sparkle, no Cocoa, minimal dyld load
// Posts notification payload to the resident ClaudeNotify app via DistributedNotificationCenter

let args = CommandLine.arguments
var payload: [String: String] = [:]
var i = 1
while i < args.count {
    switch args[i] {
    case "-title":     i += 1; if i < args.count { payload["title"] = args[i] }
    case "-message":   i += 1; if i < args.count { payload["message"] = args[i] }
    case "-sound":     i += 1; if i < args.count { payload["sound"] = args[i] }
    case "-activate":  i += 1; if i < args.count { payload["activate"] = args[i] }
    case "-workspace": i += 1; if i < args.count { payload["workspace"] = args[i] }
    case "-session":   i += 1; if i < args.count { payload["session"] = args[i] }
    case "-windowId":  i += 1; if i < args.count { payload["windowId"] = args[i] }
    default: break
    }
    i += 1
}

if payload.isEmpty { exit(0) }

// Set defaults
if payload["title"] == nil { payload["title"] = "Claude Code" }
if payload["sound"] == nil { payload["sound"] = "default" }

guard let data = try? JSONSerialization.data(withJSONObject: payload),
      let jsonString = String(data: data, encoding: .utf8)
else { exit(1) }

DistributedNotificationCenter.default().post(
    name: Notification.Name("com.claude.notify.send"),
    object: jsonString
)

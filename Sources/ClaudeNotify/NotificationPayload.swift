import Foundation

struct NotificationPayload {
    var title: String = "Claude Code"
    var message: String = ""
    var sound: String = "default"
    var activate: String = ""
    var workspace: String = ""
    var session: String = ""
    var windowId: String = ""

    var dictionary: [String: String] {
        [
            "title": title, "message": message, "sound": sound,
            "activate": activate, "workspace": workspace,
            "session": session, "windowId": windowId
        ]
    }

    static func fromArgs(_ args: [String]) -> NotificationPayload {
        var payload = NotificationPayload()
        var i = 1
        while i < args.count {
            switch args[i] {
            case "-title":     i += 1; if i < args.count { payload.title = args[i] }
            case "-message":   i += 1; if i < args.count { payload.message = args[i] }
            case "-sound":     i += 1; if i < args.count { payload.sound = args[i] }
            case "-activate":  i += 1; if i < args.count { payload.activate = args[i] }
            case "-workspace": i += 1; if i < args.count { payload.workspace = args[i] }
            case "-session":   i += 1; if i < args.count { payload.session = args[i] }
            case "-windowId":  i += 1; if i < args.count { payload.windowId = args[i] }
            default: break
            }
            i += 1
        }
        return payload
    }

    static func fromJSON(_ jsonString: String) -> NotificationPayload? {
        guard let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String]
        else { return nil }
        var payload = NotificationPayload()
        if let v = dict["title"]     { payload.title = v }
        if let v = dict["message"]   { payload.message = v }
        if let v = dict["sound"]     { payload.sound = v }
        if let v = dict["activate"]  { payload.activate = v }
        if let v = dict["workspace"] { payload.workspace = v }
        if let v = dict["session"]   { payload.session = v }
        if let v = dict["windowId"]  { payload.windowId = v }
        return payload
    }

    func toJSON() -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: dictionary),
              let string = String(data: data, encoding: .utf8)
        else { return nil }
        return string
    }

    static func hasNotificationArgs(_ args: [String]) -> Bool {
        args.contains("-title") || args.contains("-message")
    }
}

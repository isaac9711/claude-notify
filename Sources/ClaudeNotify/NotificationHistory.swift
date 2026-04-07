import Foundation

struct NotificationRecord {
    let payload: NotificationPayload
    let subtitle: String
    let timestamp: Date
}

class NotificationHistory {
    private let maxCount = 10
    private(set) var records: [NotificationRecord] = []

    func add(payload: NotificationPayload, subtitle: String) {
        let record = NotificationRecord(payload: payload, subtitle: subtitle, timestamp: Date())
        records.insert(record, at: 0)
        if records.count > maxCount {
            records.removeLast()
        }
    }

    func clear() {
        records.removeAll()
    }
}

import Foundation

/// One alert Catch wants iOS to deliver.
struct PlannedReminder: Equatable {
    enum Kind: Equatable { case main, nudge }

    let id: String
    let itemID: UUID
    let kind: Kind
    let title: String
    let body: String
    let fireDate: Date
}

/// Works out the pending alerts from the items. Pure, so it can be tested
/// without the notification center.
enum ReminderPlanner {
    /// The nudge fires once, this long after the first alert.
    static let nudgeDelay: TimeInterval = 30 * 60
    /// iOS keeps at most 64 pending requests per app; leave some room.
    static let limit = 60

    static func plan(items: [Item], now: Date, nudgeDefault: Bool) -> [PlannedReminder] {
        var result: [PlannedReminder] = []
        for item in items where item.list == .later && !item.isDone {
            // Place reminders need location monitoring; they arrive with Places.
            guard case .date(let date)? = item.reminder else { continue }
            if date > now {
                result.append(PlannedReminder(id: "item-\(item.id.uuidString)", itemID: item.id, kind: .main,
                                              title: item.text, body: item.note ?? "From your Later list",
                                              fireDate: date))
            }
            let nudgeDate = date.addingTimeInterval(nudgeDelay)
            if item.nudge ?? nudgeDefault, nudgeDate > now {
                result.append(PlannedReminder(id: "item-\(item.id.uuidString)-nudge", itemID: item.id, kind: .nudge,
                                              title: item.text, body: "Still on your list",
                                              fireDate: nudgeDate))
            }
        }
        return Array(result.sorted { $0.fireDate < $1.fireDate }.prefix(limit))
    }
}

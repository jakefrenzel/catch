import Foundation

/// A circle iOS watches for a place reminder.
struct PlaceRegion: Equatable {
    let latitude: Double
    let longitude: Double
    let radius: Double
    /// Fire on arriving; otherwise on leaving.
    let onArrive: Bool
}

/// One alert Catch wants iOS to deliver.
struct PlannedReminder: Equatable {
    enum Kind: Equatable { case main, nudge, place }

    let id: String
    let itemID: UUID
    let kind: Kind
    let title: String
    let body: String
    /// For place reminders, .distantFuture (they fire on location, not time).
    let fireDate: Date
    var region: PlaceRegion?
}

/// Works out the pending alerts from the items. Pure, so it can be tested
/// without the notification center.
enum ReminderPlanner {
    /// The nudge fires once, this long after the first alert.
    static let nudgeDelay: TimeInterval = 30 * 60
    /// iOS keeps at most 64 pending requests per app; leave some room.
    static let limit = 60
    /// iOS watches at most 20 regions per app.
    static let placeLimit = 15

    static func plan(items: [Item], now: Date, nudgeDefault: Bool) -> [PlannedReminder] {
        var result: [PlannedReminder] = []
        var places: [PlannedReminder] = []
        for item in items where item.list == .later && !item.isDone {
            if case .place(let trigger, let place)? = item.reminder {
                places.append(PlannedReminder(
                    id: "item-\(item.id.uuidString)-place", itemID: item.id, kind: .place,
                    title: item.text,
                    body: trigger == .leave ? "You’re leaving \(place.name)" : "You’re at \(place.name)",
                    fireDate: .distantFuture,
                    region: PlaceRegion(latitude: place.latitude, longitude: place.longitude,
                                        radius: place.radiusMeters, onArrive: trigger == .arrive)))
                continue
            }
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
        let placed = Array(places.prefix(placeLimit))
        let timed = result.sorted { $0.fireDate < $1.fireDate }.prefix(limit - placed.count)
        return Array(timed) + placed
    }
}

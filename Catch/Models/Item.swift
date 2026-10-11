import Foundation
import SwiftData

// Every stored property has a default and relationships are optional so the
// schema stays compatible with CloudKit sync later.

@Model
final class Item {
    var id: UUID = UUID()
    var text: String = ""
    var note: String?
    var listRaw: String = "inbox"
    var capturedAt: Date = Date()
    var completedAt: Date?

    // Reminder (Later items). Either a date, or a place trigger plus a place.
    var remindAt: Date?
    var placeTriggerRaw: String?
    var place: Place?
    /// Nudge again 30 min after a missed reminder. nil means "use the Settings default".
    var nudge: Bool?

    /// Why the item is in Now, shown under Up first ("Sorted into Now from Inbox").
    var reason: String?
    /// Pushed to tomorrow during the evening wrap-up.
    var movedToTomorrow: Bool = false
    /// When it was pushed, so it comes back on the right morning.
    var movedToTomorrowAt: Date?

    init(text: String, list: ListKind = .inbox, capturedAt: Date = .now) {
        self.text = text
        self.listRaw = list.rawValue
        self.capturedAt = capturedAt
    }

    var list: ListKind {
        get { ListKind(rawValue: listRaw) ?? .inbox }
        set { listRaw = newValue.rawValue }
    }

    var isDone: Bool { completedAt != nil }

    /// In Now, not done and not moved to tomorrow. These count toward the Now limit.
    var isOpenInNow: Bool { list == .now && !isDone && !movedToTomorrow }

    var reminder: ReminderTime? {
        get {
            if let place, let raw = placeTriggerRaw, let trigger = PlaceTrigger(rawValue: raw) {
                return .place(trigger, place)
            }
            if let remindAt { return .date(remindAt) }
            return nil
        }
        set {
            switch newValue {
            case .date(let date):
                remindAt = date
                placeTriggerRaw = nil
                place = nil
            case .place(let trigger, let newPlace):
                remindAt = nil
                placeTriggerRaw = trigger.rawValue
                place = newPlace
            case nil:
                remindAt = nil
                placeTriggerRaw = nil
                place = nil
            }
        }
    }
}

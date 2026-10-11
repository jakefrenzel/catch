import Foundation

/// A copy of everything an action can change on an item, used to undo it.
struct ItemSnapshot {
    let id: UUID
    let text: String
    let note: String?
    let listRaw: String
    let capturedAt: Date
    let completedAt: Date?
    let remindAt: Date?
    let placeTriggerRaw: String?
    let place: Place?
    let nudge: Bool?
    let reason: String?
    let movedToTomorrow: Bool

    init(_ item: Item) {
        id = item.id
        text = item.text
        note = item.note
        listRaw = item.listRaw
        capturedAt = item.capturedAt
        completedAt = item.completedAt
        remindAt = item.remindAt
        placeTriggerRaw = item.placeTriggerRaw
        place = item.place
        nudge = item.nudge
        reason = item.reason
        movedToTomorrow = item.movedToTomorrow
    }

    func apply(to item: Item) {
        item.text = text
        item.note = note
        item.listRaw = listRaw
        item.capturedAt = capturedAt
        item.completedAt = completedAt
        item.remindAt = remindAt
        item.placeTriggerRaw = placeTriggerRaw
        item.place = place
        item.nudge = nudge
        item.reason = reason
        item.movedToTomorrow = movedToTomorrow
    }

    /// A new item with the same contents and id, for undoing a delete.
    func recreate() -> Item {
        let item = Item(text: text)
        item.id = id
        apply(to: item)
        return item
    }
}

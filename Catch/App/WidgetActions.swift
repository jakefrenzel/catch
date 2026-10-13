import Foundation
import WidgetKit

/// What widget and Live Activity buttons do, in the app's process (see WidgetIntents).
/// These can run from a background launch, so each one brings the day up to date
/// first and finishes rescheduling reminders and refreshing widgets before returning.
@MainActor
enum WidgetActions {
    private static var services: AppServices { .shared }

    static func complete(itemID: String) async {
        services.model.refreshClock()
        guard let item = services.store.allItems().first(where: { $0.id.uuidString == itemID }) else { return }
        services.store.setDone(item, true)
        await services.model.syncReminders()
    }

    static func complete(stepID: String) async {
        services.model.refreshClock()
        let steps = services.store.projects().flatMap(\.orderedSteps)
        guard let step = steps.first(where: { $0.id.uuidString == stepID }) else { return }
        services.store.setDone(step, true)
        await services.model.syncReminders()
    }

    /// Skips on the widget only; resets once everything has been skipped.
    static func skip(id: String) async {
        guard let uuid = UUID(uuidString: id) else { return }
        services.model.refreshClock()
        let candidates = services.store.upFirstCandidates()
        var skipped = SharedStore.widgetSkipped
        skipped.insert(uuid)
        if candidates.allSatisfy({ skipped.contains($0.key) }) { skipped = [] }
        SharedStore.widgetSkipped = skipped
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func snooze(itemID: String) async {
        services.model.refreshClock()
        guard let item = services.store.allItems().first(where: { $0.id.uuidString == itemID }) else { return }
        services.store.snooze(item)
        await services.model.syncReminders()
    }

    static func allToTomorrow() async {
        services.model.refreshClock()
        services.store.moveAllToTomorrow()
        await services.model.syncReminders()
    }

    static func startTalking() {
        services.model.startListening(tapToTalk: true)
    }

    static func finishVoiceActivity() async {
        await services.voiceActivity.finish()
    }

    /// The Live Activity's Undo: removes exactly the item it just saved, not
    /// whatever was done last in the app.
    static func undoCapture(itemID: String) async {
        if let item = services.store.allItems().first(where: { $0.id.uuidString == itemID }) {
            services.store.delete(item)
            services.model.closeWhatWasDeleted()
        }
        await services.voiceActivity.endNow()
        await services.model.syncReminders()
    }
}

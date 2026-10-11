import Foundation
import WidgetKit

/// What widget buttons do, in the app's process (see WidgetIntents).
@MainActor
enum WidgetActions {
    private static var services: AppServices { .shared }

    static func complete(itemID: String) {
        guard let item = services.store.allItems().first(where: { $0.id.uuidString == itemID }) else { return }
        services.store.setDone(item, true)
        reload()
    }

    static func complete(stepID: String) {
        let steps = services.store.projects().flatMap(\.orderedSteps)
        guard let step = steps.first(where: { $0.id.uuidString == stepID }) else { return }
        services.store.setDone(step, true)
        reload()
    }

    /// Skips on the widget only; resets once everything has been skipped.
    static func skip(id: String) {
        guard let uuid = UUID(uuidString: id) else { return }
        let candidates = services.store.upFirstCandidates()
        var skipped = SharedStore.widgetSkipped
        skipped.insert(uuid)
        if candidates.allSatisfy({ skipped.contains($0.key) }) { skipped = [] }
        SharedStore.widgetSkipped = skipped
        reload()
    }

    static func snooze(itemID: String) {
        guard let item = services.store.allItems().first(where: { $0.id.uuidString == itemID }) else { return }
        services.store.snooze(item)
        reload()
    }

    static func allToTomorrow() {
        services.store.moveAllToTomorrow()
        reload()
    }

    static func startTalking() {
        services.model.startListening(tapToTalk: true)
    }

    static func finishVoiceActivity() async {
        await services.voiceActivity.finish()
    }

    static func undoVoiceCatch() async {
        services.store.undo()
        await services.voiceActivity.endNow()
        reload()
    }

    static func reload() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}

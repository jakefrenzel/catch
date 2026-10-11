import AppIntents
import Foundation

// Buttons on the widgets. These are compiled into both the app and the widget
// extension. As LiveActivityIntents they run in the app's process, so changes
// go through the same store as the screens (and reschedule reminders); the
// extension's copy never performs anything.

struct CompleteItemIntent: AppIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Mark Done"
    static let isDiscoverable = false

    @Parameter(title: "Item") var itemID: String

    init() {}
    init(itemID: UUID) { self.itemID = itemID.uuidString }

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        await WidgetActions.complete(itemID: itemID)
        #endif
        return .result()
    }
}

struct CompleteStepIntent: AppIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Mark Step Done"
    static let isDiscoverable = false

    @Parameter(title: "Step") var stepID: String

    init() {}
    init(stepID: UUID) { self.stepID = stepID.uuidString }

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        await WidgetActions.complete(stepID: stepID)
        #endif
        return .result()
    }
}

struct SkipUpFirstIntent: AppIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Skip"
    static let isDiscoverable = false

    @Parameter(title: "Suggestion") var id: String

    init() {}
    init(id: UUID) { self.id = id.uuidString }

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        await WidgetActions.skip(id: id)
        #endif
        return .result()
    }
}

struct SnoozeItemIntent: AppIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "In 1 Hour"
    static let isDiscoverable = false

    @Parameter(title: "Item") var itemID: String

    init() {}
    init(itemID: UUID) { self.itemID = itemID.uuidString }

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        await WidgetActions.snooze(itemID: itemID)
        #endif
        return .result()
    }
}

struct AllToTomorrowIntent: AppIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "All to Tomorrow"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        await WidgetActions.allToTomorrow()
        #endif
        return .result()
    }
}

/// The Control Center / Lock Screen control: opens Catch listening.
struct StartTalkingIntent: AppIntent {
    static let title: LocalizedStringResource = "Catch a Thought by Voice"
    static let description = IntentDescription("Opens Catch and starts listening.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        await WidgetActions.startTalking()
        #endif
        return .result()
    }
}

/// The Live Activity's Save: stop listening now and save what was heard.
struct FinishVoiceActivityIntent: AppIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Save"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        await WidgetActions.finishVoiceActivity()
        #endif
        return .result()
    }
}

/// The Live Activity's Undo after saving.
struct UndoVoiceCatchIntent: AppIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Undo"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        await WidgetActions.undoVoiceCatch()
        #endif
        return .result()
    }
}

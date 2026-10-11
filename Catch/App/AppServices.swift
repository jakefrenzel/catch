import SwiftData
import SwiftUI
import UserNotifications

/// The one database, store and model for the whole app. The SwiftUI scene and
/// App Intents (Siri, Shortcuts) both use this, so a shortcut run while the app
/// is closed works on the same data the screens show.
@MainActor
final class AppServices {
    static let shared = AppServices()

    let container: ModelContainer
    let settingsStore: SettingsStore
    let store: CatchStore
    let model: AppModel
    let voiceActivity: VoiceActivityController
    private let notificationDelegate = NotificationDelegate()

    private init() {
        do {
            container = try ModelContainer(for: Schema(CatchSchema.models))
        } catch {
            fatalError("Couldn't open the Catch database: \(error)")
        }

        // Shared with the widget extension through the App Group.
        settingsStore = SettingsStore(defaults: SharedStore.defaults)
        store = CatchStore(context: container.mainContext, settingsStore: settingsStore)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-seedSampleData") {
            SampleData.seedIfEmpty(store)
        }
        #endif

        let scheduler = SystemNotificationScheduler()
        scheduler.registerCategories()
        var voice: VoiceInput?
        #if DEBUG
        // The simulator in CI has no microphone: type out a sample sentence instead.
        if ProcessInfo.processInfo.arguments.contains("-voiceDemo") {
            voice = DemoVoiceInput()
        }
        #endif
        model = AppModel(store: store, settingsStore: settingsStore, notifications: scheduler, voice: voice)
        voiceActivity = VoiceActivityController(model: model)
        notificationDelegate.model = model
        UNUserNotificationCenter.current().delegate = notificationDelegate
        model.startOnboardingIfNeeded()
    }
}

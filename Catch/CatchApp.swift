import SwiftData
import SwiftUI
import UserNotifications

@main
struct CatchApp: App {
    private let container: ModelContainer
    private let notificationDelegate = NotificationDelegate()
    @State private var model: AppModel

    init() {
        let container: ModelContainer
        do {
            container = try ModelContainer(for: Schema(CatchSchema.models))
        } catch {
            fatalError("Couldn't open the Catch database: \(error)")
        }
        self.container = container

        let settingsStore = SettingsStore()
        let store = CatchStore(context: container.mainContext, settingsStore: settingsStore)
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
        let model = AppModel(store: store, settingsStore: settingsStore, notifications: scheduler, voice: voice)
        notificationDelegate.model = model
        UNUserNotificationCenter.current().delegate = notificationDelegate
        model.startOnboardingIfNeeded()
        _model = State(initialValue: model)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
        }
        .modelContainer(container)
    }
}

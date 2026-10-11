import SwiftData
import SwiftUI

@main
struct CatchApp: App {
    private let container: ModelContainer
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
        _model = State(initialValue: AppModel(store: store, settingsStore: settingsStore))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
        }
        .modelContainer(container)
    }
}

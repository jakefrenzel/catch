import SwiftData
import SwiftUI

@main
struct CatchApp: App {
    private let container: ModelContainer
    @State private var model: AppModel

    init() {
        let services = AppServices.shared
        container = services.container
        _model = State(initialValue: services.model)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
        }
        .modelContainer(container)
    }
}

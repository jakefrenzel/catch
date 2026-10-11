import SwiftData
import SwiftUI

@main
struct CatchApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: CatchSchema.models)
    }
}

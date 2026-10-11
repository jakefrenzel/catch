import AppIntents
import SwiftUI

// 11h / 11i: Siri and the six App Shortcuts. These run inside the app's
// process and use AppServices, so they share the screens' data.

struct CatchThoughtIntent: AppIntent {
    static let title: LocalizedStringResource = "Catch a Thought"
    static let description = IntentDescription("Saves a thought to Inbox, or to Later if it hears a time.")

    @Parameter(title: "Thought", requestValueDialog: "What's on your mind?")
    var text: String

    static var parameterSummary: some ParameterSummary {
        Summary("Catch \(\.$text)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        AppServices.shared.model.refreshClock()
        guard let saved = ShortcutActions.catchThought(text, store: AppServices.shared.store) else {
            throw $text.needsValueError("What's on your mind?")
        }
        return .result(dialog: "Saved to \(saved.destination).", view: SavedSnippet(saved: saved))
    }
}

struct AddToNowIntent: AppIntent {
    static let title: LocalizedStringResource = "Add to Now"
    static let description = IntentDescription("Adds something to Now, or to Inbox if Now is full.")

    @Parameter(title: "Item", requestValueDialog: "What should go in Now?")
    var text: String

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$text) to Now")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        AppServices.shared.model.refreshClock()
        guard let saved = ShortcutActions.addToNow(text, store: AppServices.shared.store) else {
            throw $text.needsValueError("What should go in Now?")
        }
        return .result(dialog: "Saved to \(saved.destination).", view: SavedSnippet(saved: saved))
    }
}

struct UpFirstIntent: AppIntent {
    static let title: LocalizedStringResource = "What's Up First?"
    static let description = IntentDescription("Tells you the one thing to do next.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // A morning question should see what came back from last night.
        AppServices.shared.model.refreshClock()
        return .result(dialog: "\(ShortcutActions.upFirst(store: AppServices.shared.store))")
    }
}

struct ReadNowListIntent: AppIntent {
    static let title: LocalizedStringResource = "Read My Now List"
    static let description = IntentDescription("Reads what's open in Now.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        AppServices.shared.model.refreshClock()
        return .result(dialog: "\(ShortcutActions.nowList(store: AppServices.shared.store))")
    }
}

struct WrapUpDayIntent: AppIntent {
    static let title: LocalizedStringResource = "Wrap Up My Day"
    static let description = IntentDescription("Moves what's left in Now to tomorrow and finishes the day.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let services = AppServices.shared
        services.model.refreshClock()
        return .result(dialog: "\(ShortcutActions.wrapUp(store: services.store, settingsStore: services.settingsStore))")
    }
}

struct SortInboxIntent: AppIntent {
    static let title: LocalizedStringResource = "Sort My Inbox"
    static let description = IntentDescription("Opens Catch on the Inbox.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        let model = AppServices.shared.model
        model.projectPath = []
        model.tab = .inbox
        return .result()
    }
}

/// The Siri card's Undo.
struct UndoCatchIntent: AppIntent {
    static let title: LocalizedStringResource = "Undo Catch"
    static let isDiscoverable = false

    @Parameter(title: "Item") var itemID: String

    init() {}
    init(itemID: UUID) { self.itemID = itemID.uuidString }

    /// Removes exactly the item Siri saved, not whatever was done last in the app.
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let services = AppServices.shared
        if let item = services.store.allItems().first(where: { $0.id.uuidString == itemID }) {
            services.store.delete(item)
            await services.model.syncReminders()
        }
        return .result(dialog: "Undone.")
    }
}

/// The Siri card's Open Catch.
struct OpenCatchIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Catch"
    static let isDiscoverable = false
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        .result()
    }
}

/// 11h: Saved, the title, where it went, Undo and Open Catch.
struct SavedSnippet: View {
    let saved: ShortcutActions.Saved

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.green)
                Text("Saved")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink2)
            }
            Text(saved.title)
                .font(.headline)
            Text(saved.destination)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(saved.destination.hasPrefix("Later") ? Theme.orangeText : Theme.blue)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(saved.destination.hasPrefix("Later") ? Theme.orangeTint : Theme.blueTint,
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            HStack(spacing: 10) {
                Button(intent: UndoCatchIntent(itemID: saved.itemID)) {
                    Text("Undo").frame(maxWidth: .infinity)
                }
                Button(intent: OpenCatchIntent()) {
                    Text("Open Catch").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

struct CatchShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: CatchThoughtIntent(),
                    phrases: ["Catch a thought in \(.applicationName)",
                              "Add a thought to \(.applicationName)",
                              "\(.applicationName) a thought"],
                    shortTitle: "Catch a thought",
                    systemImageName: "plus.circle")
        AppShortcut(intent: UpFirstIntent(),
                    phrases: ["What's up first in \(.applicationName)",
                              "What's next in \(.applicationName)"],
                    shortTitle: "What's up first?",
                    systemImageName: "arrow.right.circle")
        AppShortcut(intent: AddToNowIntent(),
                    phrases: ["Add to Now in \(.applicationName)"],
                    shortTitle: "Add to Now",
                    systemImageName: "sun.max")
        AppShortcut(intent: WrapUpDayIntent(),
                    phrases: ["Wrap up my day in \(.applicationName)"],
                    shortTitle: "Wrap up my day",
                    systemImageName: "moon")
        AppShortcut(intent: ReadNowListIntent(),
                    phrases: ["What's in my \(.applicationName) Now list",
                              "Read my Now list in \(.applicationName)"],
                    shortTitle: "Read my Now list",
                    systemImageName: "list.bullet")
        AppShortcut(intent: SortInboxIntent(),
                    phrases: ["Sort my \(.applicationName) Inbox"],
                    shortTitle: "Sort my Inbox",
                    systemImageName: "tray")
    }
}

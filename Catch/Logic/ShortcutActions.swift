import Foundation

/// What Siri and the Shortcuts app can do, separate from App Intents so it can be tested.
@MainActor
enum ShortcutActions {
    /// What the Siri card shows after saving.
    struct Saved: Equatable {
        let itemID: UUID
        let title: String
        /// "Inbox", "Now", or "Later · Sat 10 AM".
        let destination: String
    }

    /// "Catch …": Inbox, Later when a time is heard, or Someday when it's said.
    /// Never a project step, so Siri's result is predictable.
    static func catchThought(_ text: String, store: CatchStore, formatter: ReminderFormatter = .init()) -> Saved? {
        let now = store.currentDate()
        let parse = VoiceParser.parse(text, projects: [], afterWork: store.settings.afterWork,
                                      now: now, calendar: store.calendar)
        guard !parse.title.isEmpty else { return nil }
        let result: CatchStore.CaptureResult?
        if let date = parse.date {
            result = store.capture(parse.title, to: .later, remindAt: date)
        } else {
            result = store.capture(parse.title, to: parse.isSomeday ? .someday : .inbox)
        }
        guard let item = result?.item else { return nil }
        return Saved(itemID: item.id, title: item.text, destination: destination(of: item, now: now, formatter: formatter))
    }

    /// "Add … to Now". A full Now puts it in Inbox and says so.
    static func addToNow(_ text: String, store: CatchStore) -> Saved? {
        guard let result = store.capture(text, to: .now) else { return nil }
        return Saved(itemID: result.item.id, title: result.item.text,
                     destination: result.redirectedToInbox ? "Inbox (Now is full)" : "Now")
    }

    static func upFirst(store: CatchStore) -> String {
        guard let candidate = UpFirst().current(in: store.upFirstCandidates()) else {
            return "Nothing's up first. Today is clear."
        }
        return "Up first: \(candidate.title). \(candidate.reason)."
    }

    static func nowList(store: CatchStore) -> String {
        let titles = store.openNowItems.map(\.text)
        switch titles.count {
        case 0: return "Nothing in Now."
        case 1: return "In Now: \(titles[0])."
        default:
            return "In Now: \(titles.dropLast().joined(separator: ", ")) and \(titles[titles.count - 1])."
        }
    }

    /// "Wrap up my day": everything open in Now moves to tomorrow and the day is finished.
    static func wrapUp(store: CatchStore, settingsStore: SettingsStore) -> String {
        let moved = store.moveAllToTomorrow()
        settingsStore.dayFinishedOn = store.currentDate()
        switch moved {
        case 0: return "Day finished. Nothing was left in Now."
        case 1: return "Day finished. Moved 1 thing to tomorrow."
        default: return "Day finished. Moved \(moved) things to tomorrow."
        }
    }

    private static func destination(of item: Item, now: Date, formatter: ReminderFormatter) -> String {
        switch item.list {
        case .later:
            guard let reminder = item.reminder else { return "Later" }
            return "Later · \(formatter.label(for: reminder, now: now))"
        default:
            return item.list.title
        }
    }
}

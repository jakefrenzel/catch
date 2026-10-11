import Foundation
import SwiftData
@testable import Catch

/// A clock that moves forward one minute every time it's read, so captures
/// have distinct, ordered timestamps.
final class TestClock {
    let calendar: Calendar
    var date: Date

    init() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        self.calendar = calendar
        // Friday, October 9, 2026, 12:00 UTC
        self.date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 9, hour: 12))!
    }

    func tick() -> Date {
        date = date.addingTimeInterval(60)
        return date
    }

    func at(day: Int, hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }
}

/// Records what would be scheduled instead of touching the notification center.
@MainActor
final class FakeNotifications: NotificationScheduling {
    var currentPermission: NotificationPermission = .allowed
    var grantsPermission = true
    var requestCount = 0
    var openedSystemSettings = false
    var pending: [PlannedReminder] = []

    func permission() async -> NotificationPermission { currentPermission }

    func requestAuthorization() async -> Bool {
        requestCount += 1
        currentPermission = grantsPermission ? .allowed : .denied
        return grantsPermission
    }

    func replacePending(with reminders: [PlannedReminder]) async { pending = reminders }

    func openSystemSettings() { openedSystemSettings = true }
}

/// A store backed by an in-memory database and throwaway settings.
@MainActor
struct TestEnvironment {
    let container: ModelContainer
    let settingsStore: SettingsStore
    let clock: TestClock
    let store: CatchStore

    init() throws {
        container = try ModelContainer(
            for: Schema(CatchSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        settingsStore = SettingsStore(defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!)
        let clock = TestClock()
        self.clock = clock
        store = CatchStore(
            context: ModelContext(container),
            settingsStore: settingsStore,
            calendar: clock.calendar,
            now: { clock.tick() }
        )
    }

    /// Captures straight into a list, failing loudly if Now was full.
    @discardableResult
    func add(_ text: String, to list: ListKind) -> Item {
        let result = store.capture(text, to: list)!
        precondition(result.item.list == list, "\(text) landed in \(result.item.list)")
        return result.item
    }

    @discardableResult
    func addProject(_ name: String, steps: [(String, String)]) -> Project {
        var draft = ProjectDraft(name: name)
        var phase: String?
        for (text, stepPhase) in steps {
            if stepPhase != phase {
                draft.rows.append(.phase(stepPhase))
                phase = stepPhase
            }
            draft.rows.append(.step(text))
        }
        return store.createProject(from: draft)!
    }
}

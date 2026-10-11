import XCTest
@testable import Catch

@MainActor
final class WidgetTimelineTests: XCTestCase {
    private func snapshot(_ env: TestEnvironment, at date: Date, skipped: Set<UUID> = []) -> WidgetSnapshot {
        WidgetTimeline.snapshot(at: date, items: env.store.allItems(), projects: env.store.projects(),
                                settings: env.store.settings, skipped: skipped, calendar: env.clock.calendar,
                                formatter: ReminderFormatter(calendar: env.clock.calendar,
                                                             locale: Locale(identifier: "en_US")))
    }

    func testMorningShowsUpFirstAndTheRestOfNow() throws {
        let env = try TestEnvironment()
        let invoice = env.add("Send invoice", to: .now)
        env.add("Call Dana", to: .now)
        env.add("Idea", to: .inbox)

        let result = snapshot(env, at: env.clock.at(day: 9, hour: 13))

        guard case .upFirst(let itemID, _, let title, _) = result.mode else { return XCTFail("Expected Up first") }
        XCTAssertEqual(itemID, invoice.id)
        XCTAssertEqual(title, "Send invoice")
        XCTAssertEqual(result.listTitle, "NOW · 2 OF 3")
        XCTAssertEqual(result.list, ["Call Dana"])
        XCTAssertEqual(result.inboxCount, 1)
    }

    func testSkippedSuggestionMovesOn() throws {
        let env = try TestEnvironment()
        let first = env.add("First", to: .now)
        env.add("Second", to: .now)

        let result = snapshot(env, at: env.clock.at(day: 9, hour: 13), skipped: [first.id])

        guard case .upFirst(_, _, let title, _) = result.mode else { return XCTFail("Expected Up first") }
        XCTAssertEqual(title, "Second")
    }

    func testProjectStepCanBeUpFirst() throws {
        let env = try TestEnvironment()
        let project = env.addProject("Reno", steps: [("Measure", "Plan")])

        let result = snapshot(env, at: env.clock.at(day: 9, hour: 13))

        guard case .upFirst(let itemID, let stepID, _, _) = result.mode else { return XCTFail("Expected Up first") }
        XCTAssertNil(itemID)
        XCTAssertEqual(stepID, project.orderedSteps.first?.id)
    }

    func testDueLaterReminderTakesTheTopSpot() throws {
        let env = try TestEnvironment()
        env.add("Send invoice", to: .now)
        let due = try XCTUnwrap(env.store.capture("Pick up dry cleaning", to: .later,
                                                  remindAt: env.clock.at(day: 9, hour: 17, minute: 30))).item

        let before = snapshot(env, at: env.clock.at(day: 9, hour: 17))
        let after = snapshot(env, at: env.clock.at(day: 9, hour: 17, minute: 31))

        guard case .upFirst = before.mode else { return XCTFail("Not due yet") }
        guard case .laterDue(let itemID, _, let time, _) = after.mode else { return XCTFail("Expected Later") }
        XCTAssertEqual(itemID, due.id)
        XCTAssertEqual(time.replacingOccurrences(of: "\u{202F}", with: " "), "5:30 PM")
        XCTAssertEqual(after.listTitle, "STILL IN NOW")
        XCTAssertEqual(after.list, ["Send invoice"])
    }

    func testEveningShowsWhatsLeft() throws {
        let env = try TestEnvironment()
        env.add("A", to: .now)
        env.add("B", to: .now)
        let done = env.add("C", to: .now)
        env.store.setDone(done, true)

        let result = snapshot(env, at: env.clock.at(day: 9, hour: 21, minute: 5))

        guard case .evening(let left, let doneCount, _) = result.mode else { return XCTFail("Expected evening") }
        XCTAssertEqual(left, 2)
        XCTAssertEqual(doneCount, 1)
        XCTAssertEqual(result.list, ["A", "B"])
    }

    func testClearDay() throws {
        let env = try TestEnvironment()
        guard case .clear = snapshot(env, at: env.clock.at(day: 9, hour: 13)).mode else {
            return XCTFail("Expected clear")
        }
    }

    func testEntryDates() throws {
        let env = try TestEnvironment()
        env.store.capture("Today", to: .later, remindAt: env.clock.at(day: 9, hour: 17, minute: 30))
        env.store.capture("Tomorrow", to: .later, remindAt: env.clock.at(day: 10, hour: 9))
        let now = env.clock.at(day: 9, hour: 13)

        let dates = WidgetTimeline.entryDates(now: now, items: env.store.allItems(),
                                              settings: env.store.settings, calendar: env.clock.calendar)

        XCTAssertEqual(dates, [now,
                               env.clock.at(day: 9, hour: 17, minute: 30),
                               env.clock.at(day: 9, hour: 21),
                               env.clock.at(day: 10, hour: 0)])
    }

    func testDeepLinks() throws {
        let env = try TestEnvironment()
        env.settingsStore.settings.haptics = false
        let voice = FakeVoice()
        let model = AppModel(store: env.store, settingsStore: env.settingsStore,
                             notifications: FakeNotifications(), voice: voice)

        model.handle(URL(string: "catch://inbox")!)
        XCTAssertEqual(model.tab, .inbox)

        model.handle(URL(string: "catch://voice")!)
        XCTAssertTrue(model.isListening)
        XCTAssertTrue(model.isTapToTalk)
    }
}

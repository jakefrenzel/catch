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

    func testLateReminderStaysDueUntilTheDayTurnsOver() throws {
        let env = try TestEnvironment()
        env.settingsStore.settings.wrapUpStyle = .off
        let due = try XCTUnwrap(env.store.capture("Take out the bins", to: .later,
                                                  remindAt: env.clock.at(day: 9, hour: 23, minute: 30))).item

        // Past midnight it's still the same Catch day, as the timeline has no entry until 4 AM.
        let lateNight = snapshot(env, at: env.clock.at(day: 10, hour: 0, minute: 30))
        let nextMorning = snapshot(env, at: env.clock.at(day: 10, hour: 4, minute: 1))

        guard case .laterDue(let itemID, _, _, _) = lateNight.mode else { return XCTFail("Expected Later") }
        XCTAssertEqual(itemID, due.id)
        if case .laterDue = nextMorning.mode { XCTFail("Yesterday's reminder shouldn't take the top spot") }
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

    func testWidgetShowsItemsBackFromTomorrowBeforeTheAppRuns() throws {
        let env = try TestEnvironment()
        env.add("Leftover", to: .now)
        env.store.moveAllToTomorrow()

        let tonight = snapshot(env, at: env.clock.at(day: 9, hour: 22))
        let morning = snapshot(env, at: env.clock.at(day: 10, hour: 8))

        guard case .evening(let left, _, _) = tonight.mode else { return XCTFail("Expected evening") }
        XCTAssertEqual(left, 0)
        guard case .upFirst(_, _, let title, _) = morning.mode else { return XCTFail("Expected Up first") }
        XCTAssertEqual(title, "Leftover")
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
                               env.clock.at(day: 10, hour: 4)])
    }

    func testAfterMidnightTheTimelineReachesTheMorning() throws {
        let env = try TestEnvironment()
        let now = env.clock.at(day: 10, hour: 0, minute: 30)

        let dates = WidgetTimeline.entryDates(now: now, items: env.store.allItems(),
                                              settings: env.store.settings, calendar: env.clock.calendar)

        // The day turns over at 4 AM; tonight's wrap-up is the next evening's, not an entry now.
        XCTAssertEqual(dates, [now, env.clock.at(day: 10, hour: 4)])
    }

    func testWidgetNowNeverShowsMoreThanTheLimit() throws {
        let env = try TestEnvironment()
        env.add("A", to: .now)
        env.add("B", to: .now)
        env.add("C", to: .now)
        env.store.moveAllToTomorrow()
        env.add("D", to: .now)
        env.add("E", to: .now)

        let morning = snapshot(env, at: env.clock.at(day: 10, hour: 8))

        // B and C came back to a full Now; carry-over will send them to Inbox, so the widget skips them.
        guard case .upFirst(_, _, let title, _) = morning.mode else { return XCTFail("Expected Up first") }
        let shown = morning.list + [title]
        XCTAssertFalse(shown.contains("B"))
        XCTAssertFalse(shown.contains("C"))
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

final class VoiceActivityStateTests: XCTestCase {
    func testListeningCarriesHighlightedChunks() {
        let parse = VoiceParser.parse("Remind me to call Dana tomorrow at 10", projects: [],
                                      afterWork: TimeOfDay(hour: 17, minute: 30), now: .now, calendar: .current)
        let state = VoiceActivityAttributes.ContentState.listening(parse)
        XCTAssertEqual(state.phase, .listening)
        XCTAssertEqual(state.chunks.map(\.kind), ["filler", "normal", "time"])
        XCTAssertEqual(state.chunks.map(\.text), ["Remind me to", "call Dana", "tomorrow at 10"])
    }

    func testSavedState() {
        let state = VoiceActivityAttributes.ContentState.saved(title: "Call Dana", destination: "Later · Sat 10 AM")
        XCTAssertEqual(state.phase, .saved)
        XCTAssertEqual(state.savedTitle, "Call Dana")
        XCTAssertTrue(state.chunks.isEmpty)
    }
}

import XCTest
@testable import Catch

final class WrapUpTests: XCTestCase {
    private let clock = TestClock()

    private func isEvening(hour: Int, minute: Int = 0, style: CatchSettings.WrapUpStyle = .onToday) -> Bool {
        var settings = CatchSettings()
        settings.wrapUpStyle = style
        return WrapUp.isEvening(now: clock.at(day: 9, hour: hour, minute: minute),
                                settings: settings, calendar: clock.calendar)
    }

    func testEveningStartsAtWrapUpTime() {
        XCTAssertFalse(isEvening(hour: 20, minute: 59))
        XCTAssertTrue(isEvening(hour: 21))
        XCTAssertTrue(isEvening(hour: 23, minute: 59))
        // The evening runs until the day turns over at 4 AM.
        XCTAssertTrue(isEvening(hour: 0, minute: 30))
        XCTAssertFalse(isEvening(hour: 4))
        XCTAssertFalse(isEvening(hour: 12))
    }

    func testMidnightWrapUpIsNotAllDay() {
        var settings = CatchSettings()
        settings.wrapUpTime = TimeOfDay(hour: 0, minute: 0)
        func evening(_ hour: Int) -> Bool {
            WrapUp.isEvening(now: clock.at(day: 9, hour: hour), settings: settings, calendar: clock.calendar)
        }
        XCTAssertFalse(evening(12))
        XCTAssertFalse(evening(23))
        XCTAssertTrue(evening(1))
    }

    func testNoEveningWhenStyleIsOff() {
        XCTAssertFalse(isEvening(hour: 22, style: .off))
    }

    func testCardWording() {
        XCTAssertEqual(WrapUp.card(left: 2, movedToTomorrow: 0, isFinished: false),
                       .init(title: "2 left for today", subtitle: "Move them on, then finish the day", canFinish: true))
        XCTAssertEqual(WrapUp.card(left: 0, movedToTomorrow: 0, isFinished: true),
                       .init(title: "Day finished", subtitle: "Good night. Up first is ready in the morning.", canFinish: false))
        XCTAssertEqual(WrapUp.card(left: 0, movedToTomorrow: 3, isFinished: false).subtitle, "3 moved to tomorrow")
        XCTAssertEqual(WrapUp.card(left: 0, movedToTomorrow: 0, isFinished: false).subtitle, "Finish when you’re ready")
    }

    @MainActor
    func testOldDoneItemsLeaveToday() throws {
        let env = try TestEnvironment()
        let item = env.add("Done yesterday", to: .now)
        item.completedAt = env.clock.at(day: 8, hour: 18)
        let open = env.add("Still open", to: .now)
        let doneToday = env.add("Done today", to: .now)
        doneToday.completedAt = env.clock.at(day: 9, hour: 11)

        let now = env.clock.at(day: 9, hour: 12)
        XCTAssertFalse(WrapUp.isVisibleToday(item, now: now, calendar: env.clock.calendar))
        XCTAssertTrue(WrapUp.isVisibleToday(open, now: now, calendar: env.clock.calendar))
        XCTAssertTrue(WrapUp.isVisibleToday(doneToday, now: now, calendar: env.clock.calendar))
    }
}

@MainActor
final class EveningFlowTests: XCTestCase {
    private func makeModel() throws -> (AppModel, TestEnvironment) {
        let env = try TestEnvironment()
        env.settingsStore.settings.haptics = false
        return (AppModel(store: env.store, settingsStore: env.settingsStore, notifications: FakeNotifications()), env)
    }

    func testFinishMovesLeftoversAndMarksTheDay() throws {
        let (model, env) = try makeModel()
        env.add("A", to: .now)
        env.add("B", to: .now)

        model.finishDay()

        XCTAssertTrue(env.store.openNowItems.isEmpty)
        XCTAssertTrue(model.isDayFinished)
        XCTAssertEqual(model.toast?.message, "Day finished. 2 moved to tomorrow")
    }

    func testFinishWithNothingLeft() throws {
        let (model, _) = try makeModel()
        model.finishDay()
        XCTAssertEqual(model.toast?.message, "Day finished")
    }

    func testAllToTomorrow() throws {
        let (model, env) = try makeModel()
        env.add("A", to: .now)
        model.moveAllToTomorrow()
        XCTAssertEqual(model.toast?.message, "Moved 1 to tomorrow")
        model.undo()
        XCTAssertEqual(env.store.openNowItems.count, 1)
    }

    func testNewDayBringsItemsBack() throws {
        let (model, env) = try makeModel()
        let item = env.add("A", to: .now)
        env.store.moveToTomorrow(item)
        env.clock.date = env.clock.at(day: 10, hour: 9)

        model.refreshClock()

        XCTAssertFalse(item.movedToTomorrow)
        XCTAssertEqual(item.reason, "Carried over from last night")
    }

    func testSameDayDoesNotCarryOver() throws {
        let (model, env) = try makeModel()
        let item = env.add("A", to: .now)
        env.store.moveToTomorrow(item)

        model.refreshClock()

        XCTAssertTrue(item.movedToTomorrow)
    }

    func testFinishedAfterMidnightStillCountsAsTonight() throws {
        let (model, env) = try makeModel()
        env.clock.date = env.clock.at(day: 10, hour: 0, minute: 30)
        model.finishDay()
        env.clock.date = env.clock.at(day: 10, hour: 1)
        model.refreshClock()
        XCTAssertTrue(model.isDayFinished)
        env.clock.date = env.clock.at(day: 10, hour: 9)
        model.refreshClock()
        XCTAssertFalse(model.isDayFinished)
    }

    func testPinnedBarHiddenInTheEvening() throws {
        let (model, _) = try makeModel()
        model.tab = .inbox
        XCTAssertTrue(model.showsPinnedUpFirst)
        model.forceEvening = true
        XCTAssertFalse(model.showsPinnedUpFirst)
    }

    func testSettingsKeepDayState() throws {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let day = Date(timeIntervalSince1970: 1_800_000_000)
        SettingsStore(defaults: defaults).dayFinishedOn = day
        XCTAssertEqual(SettingsStore(defaults: defaults).dayFinishedOn, day)
    }
}

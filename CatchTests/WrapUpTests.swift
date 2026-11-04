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

    func testMorningWrapUpTimeIsNeverEvening() {
        var settings = CatchSettings()
        settings.wrapUpTime = TimeOfDay(hour: 4, minute: 30)
        for hour in [5, 12, 23] {
            XCTAssertFalse(WrapUp.isEvening(now: clock.at(day: 9, hour: hour), settings: settings,
                                            calendar: clock.calendar))
        }
    }

    func testDayTurnsOverAtFour() {
        let calendar = clock.calendar
        XCTAssertEqual(DayClock.day(of: clock.at(day: 10, hour: 3, minute: 59), calendar: calendar),
                       clock.at(day: 9, hour: 0))
        XCTAssertEqual(DayClock.day(of: clock.at(day: 10, hour: 4), calendar: calendar), clock.at(day: 10, hour: 0))
        XCTAssertEqual(DayClock.nextStart(after: clock.at(day: 9, hour: 22), calendar: calendar),
                       clock.at(day: 10, hour: 4))
        XCTAssertEqual(DayClock.nextStart(after: clock.at(day: 10, hour: 1), calendar: calendar),
                       clock.at(day: 10, hour: 4))
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

    func testUndoingFinishReopensTheDay() throws {
        let (model, env) = try makeModel()
        env.add("A", to: .now)
        model.finishDay()
        XCTAssertTrue(model.isDayFinished)

        model.undo()

        XCTAssertEqual(env.store.openNowItems.map(\.text), ["A"])
        XCTAssertFalse(model.isDayFinished, "The wrap-up alert can come back tonight")
    }

    func testUndoingSomethingElseLeavesTheDayFinished() throws {
        let (model, env) = try makeModel()
        env.add("A", to: .now)
        model.finishDay()
        let item = env.add("B", to: .inbox)
        model.move(item, to: .someday)

        model.undo()

        XCTAssertTrue(model.isDayFinished)
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

@MainActor
final class WrapUpSummaryTests: XCTestCase {
    private func summary(_ env: TestEnvironment) -> WrapUp.Summary {
        WrapUp.summary(items: env.store.allItems(), projects: env.store.projects(),
                       now: env.clock.at(day: 9, hour: 21), calendar: env.clock.calendar)
    }

    func testListsWhatGotDoneTodayInOrder() throws {
        let env = try TestEnvironment()
        let call = env.add("Call Dana", to: .now)
        let cleaning = env.add("Pick up dry cleaning", to: .later)
        env.add("Still open", to: .now)
        let reno = env.addProject("Kitchen reno", steps: [("Measure", "Plan"), ("Order tiles", "Plan"), ("Tile", "Build")])

        env.store.setDone(call, true)
        env.store.setDone(reno.orderedSteps[0], true)
        env.store.setDone(cleaning, true)

        let result = summary(env)
        XCTAssertEqual(result.done.map(\.title), ["Call Dana", "Measure", "Pick up dry cleaning"])
        XCTAssertEqual(result.title, "3 done today")
        XCTAssertEqual(result.stepsLine, "Including a step on Kitchen reno")
        XCTAssertEqual(result.closer?.name, "Kitchen reno")
        XCTAssertEqual(result.closer?.label, "2 steps to go")
    }

    func testLeavesOutOtherDaysAndOtherLists() throws {
        let env = try TestEnvironment()
        let yesterday = env.add("Done yesterday", to: .now)
        yesterday.completedAt = env.clock.at(day: 8, hour: 18)
        let someday = env.add("Learn pasta", to: .someday)
        someday.completedAt = env.clock.at(day: 9, hour: 13)
        let reno = env.addProject("Reno", steps: [("Measure", "Plan"), ("Order", "Plan")])
        reno.orderedSteps[0].completedAt = env.clock.at(day: 8, hour: 18)

        let result = summary(env)
        XCTAssertTrue(result.isEmpty)
        XCTAssertNil(result.closer)
    }

    func testCountsAfterMidnightAsTonight() throws {
        let env = try TestEnvironment()
        let late = env.add("Late one", to: .now)
        late.completedAt = env.clock.at(day: 10, hour: 1)

        let result = WrapUp.summary(items: env.store.allItems(), projects: [],
                                    now: env.clock.at(day: 10, hour: 2), calendar: env.clock.calendar)
        XCTAssertEqual(result.count, 1)
    }

    func testCloserPicksTheProjectNearestDone() throws {
        let env = try TestEnvironment()
        let far = env.addProject("Garden", steps: [("A", "S"), ("B", "S"), ("C", "S"), ("D", "S")])
        let near = env.addProject("Taxes", steps: [("Forms", "S"), ("File", "S")])
        env.store.setDone(far.orderedSteps[0], true)
        env.store.setDone(near.orderedSteps[0], true)
        env.store.setDone(near.orderedSteps[1], true)

        let result = summary(env)
        XCTAssertEqual(result.closer?.name, "Taxes")
        XCTAssertEqual(result.closer?.label, "Finished")
        XCTAssertEqual(result.stepsLine, "Including steps on 2 projects")
    }

    func testStepsLineWording() throws {
        let env = try TestEnvironment()
        let reno = env.addProject("Reno", steps: [("A", "S"), ("B", "S"), ("C", "S")])
        env.store.setDone(reno.orderedSteps[0], true)
        env.store.setDone(reno.orderedSteps[1], true)

        let result = summary(env)
        XCTAssertEqual(result.stepsLine, "Including 2 steps on Reno")
        XCTAssertEqual(result.closer?.label, "1 step to go")
        XCTAssertEqual(result.finishedLine(movedToTomorrow: 2), "2 done today. 2 moved to tomorrow.")
        XCTAssertEqual(result.finishedLine(movedToTomorrow: 0), "2 done today.")
    }

    func testNoStepsNoStepsLine() throws {
        let env = try TestEnvironment()
        env.store.setDone(env.add("A", to: .now), true)
        XCTAssertNil(summary(env).stepsLine)
    }
}

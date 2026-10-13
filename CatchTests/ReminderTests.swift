import XCTest
@testable import Catch

@MainActor
final class ReminderPlannerTests: XCTestCase {
    func testFutureReminderGetsAlertAndNudge() throws {
        let env = try TestEnvironment()
        let time = env.clock.at(day: 9, hour: 15)
        let item = try XCTUnwrap(env.store.capture("Call Dana", to: .later, remindAt: time)).item

        let plan = ReminderPlanner.plan(items: env.store.allItems(), now: env.clock.at(day: 9, hour: 12), nudgeDefault: true)

        XCTAssertEqual(plan.map(\.kind), [.main, .nudge])
        XCTAssertEqual(plan.map(\.fireDate), [time, time.addingTimeInterval(30 * 60)])
        XCTAssertEqual(plan.first?.id, "item-\(item.id.uuidString)")
        XCTAssertEqual(plan.first?.title, "Call Dana")
        XCTAssertEqual(plan.first?.body, "From your Later list")
    }

    func testNoteBecomesTheBody() throws {
        let env = try TestEnvironment()
        let item = try XCTUnwrap(env.store.capture("Call Dana", to: .later, remindAt: env.clock.at(day: 9, hour: 15))).item
        item.note = "About the lease"

        let plan = ReminderPlanner.plan(items: [item], now: env.clock.at(day: 9, hour: 12), nudgeDefault: false)

        XCTAssertEqual(plan.map(\.body), ["About the lease"])
    }

    func testNudgeFollowsItemThenDefault() throws {
        let env = try TestEnvironment()
        let time = env.clock.at(day: 9, hour: 15)
        let noNudge = try XCTUnwrap(env.store.capture("A", to: .later, remindAt: time)).item
        noNudge.nudge = false
        let usesDefault = try XCTUnwrap(env.store.capture("B", to: .later, remindAt: time)).item

        let plan = ReminderPlanner.plan(items: [noNudge, usesDefault], now: env.clock.at(day: 9, hour: 12), nudgeDefault: true)

        XCTAssertEqual(plan.filter { $0.kind == .nudge }.map(\.itemID), [usesDefault.id])
    }

    func testPassedAlertKeepsPendingNudge() throws {
        let env = try TestEnvironment()
        let time = env.clock.at(day: 9, hour: 12)
        env.store.capture("A", to: .later, remindAt: time)

        let plan = ReminderPlanner.plan(items: env.store.allItems(), now: time.addingTimeInterval(10 * 60), nudgeDefault: true)

        XCTAssertEqual(plan.map(\.kind), [.nudge])
    }

    func testSkipsDoneAndOtherLists() throws {
        let env = try TestEnvironment()
        let done = try XCTUnwrap(env.store.capture("Done", to: .later, remindAt: env.clock.at(day: 10, hour: 9))).item
        env.store.setDone(done, true)
        env.add("Inbox", to: .inbox)

        XCTAssertTrue(ReminderPlanner.plan(items: env.store.allItems(), now: env.clock.at(day: 9, hour: 12),
                                           nudgeDefault: true).isEmpty)
    }

    func testPlaceReminderWatchesTheRegion() throws {
        let env = try TestEnvironment()
        let office = env.store.savePlace(nil, name: "Office", address: "Mill St",
                                         latitude: 51.5, longitude: -0.08, radius: 150)
        let keys = env.add("Return the keys", to: .inbox)
        env.store.setReminder(keys, .place(.leave, office))

        let plan = ReminderPlanner.plan(items: env.store.allItems(), now: env.clock.at(day: 9, hour: 12),
                                        nudgeDefault: true)

        XCTAssertEqual(plan.map(\.kind), [.place])
        XCTAssertEqual(plan.first?.body, "You’re leaving Office")
        XCTAssertEqual(plan.first?.region, PlaceRegion(latitude: 51.5, longitude: -0.08, radius: 150, onArrive: false))
    }
}

@MainActor
final class OverdueTests: XCTestCase {
    func testIgnoredReminderMovesIntoNowAfterNudge() throws {
        let env = try TestEnvironment()
        let time = env.clock.date.addingTimeInterval(5 * 60)
        let item = try XCTUnwrap(env.store.capture("A", to: .later, remindAt: time)).item

        env.clock.date = time.addingTimeInterval(20 * 60)   // past the alert, inside the nudge window
        XCTAssertTrue(env.store.promoteOverdueLaterItems().isEmpty)

        env.clock.date = time.addingTimeInterval(31 * 60)
        XCTAssertEqual(env.store.promoteOverdueLaterItems(), [item])
        XCTAssertEqual(item.list, .now)
        XCTAssertEqual(item.reason, "Moved up from Later")
        XCTAssertNil(item.reminder)
    }

    func testWithoutNudgeMovesRightAfterTheAlert() throws {
        let env = try TestEnvironment()
        env.settingsStore.settings.nudgeDefault = false
        let time = env.clock.date.addingTimeInterval(5 * 60)
        let item = try XCTUnwrap(env.store.capture("A", to: .later, remindAt: time)).item

        env.clock.date = time.addingTimeInterval(60)
        env.store.promoteOverdueLaterItems()

        XCTAssertEqual(item.list, .now)
    }

    func testFullNowLeavesItInLater() throws {
        let env = try TestEnvironment()
        env.add("A", to: .now)
        env.add("B", to: .now)
        env.add("C", to: .now)
        let time = env.clock.date.addingTimeInterval(5 * 60)
        let item = try XCTUnwrap(env.store.capture("D", to: .later, remindAt: time)).item

        env.clock.date = time.addingTimeInterval(2 * 60 * 60)
        env.store.promoteOverdueLaterItems()

        XCTAssertEqual(item.list, .later)
    }

    func testSnoozeIsAnHourFromNow() throws {
        let env = try TestEnvironment()
        let item = env.add("A", to: .later)
        env.store.snooze(item)
        XCTAssertEqual(item.remindAt, env.clock.date.addingTimeInterval(60 * 60))
        XCTAssertEqual(item.list, .later)
    }
}

@MainActor
final class NotificationFlowTests: XCTestCase {
    private func makeModel(_ fake: FakeNotifications? = nil) throws -> (AppModel, TestEnvironment, FakeNotifications) {
        // Created here rather than as a default argument, which isn't on the main actor.
        let fake = fake ?? FakeNotifications()
        let env = try TestEnvironment()
        env.settingsStore.settings.haptics = false
        return (AppModel(store: env.store, settingsStore: env.settingsStore, notifications: fake), env, fake)
    }

    func testSyncSchedulesLaterItems() async throws {
        let (model, env, fake) = try makeModel()
        env.store.capture("Call Dana", to: .later, remindAt: env.clock.at(day: 10, hour: 9))

        await model.syncReminders()

        XCTAssertEqual(fake.pending.map(\.title), ["Call Dana", "Call Dana"])
    }

    func testWrapUpAlertWhenSomethingIsLeft() async throws {
        let (model, env, fake) = try makeModel()
        env.add("A", to: .now)
        env.add("B", to: .now)

        await model.syncReminders()

        let wrapUp = try XCTUnwrap(fake.pending.first { $0.kind == .wrapUp })
        XCTAssertNil(wrapUp.itemID)
        XCTAssertEqual(wrapUp.fireDate, env.clock.at(day: 9, hour: 21))
        XCTAssertTrue(wrapUp.body.hasPrefix("2 things left"))

        model.finishDay()
        await model.syncReminders()
        XCTAssertFalse(fake.pending.contains { $0.kind == .wrapUp }, "No alert once the day is finished")
    }

    func testNoWrapUpAlertForAMorningTime() {
        let clock = TestClock()
        var settings = CatchSettings()
        settings.wrapUpTime = TimeOfDay(hour: 9, minute: 0)

        let planned = ReminderPlanner.wrapUp(openInNow: 2, settings: settings, dayFinished: false,
                                             now: clock.at(day: 9, hour: 7), calendar: clock.calendar)

        XCTAssertTrue(planned.isEmpty, "Today never shows a morning wrap-up, so the alert shouldn't either")
    }

    func testNoWrapUpAlertWhenNowIsEmpty() async throws {
        let (model, _, fake) = try makeModel()
        await model.syncReminders()
        XCTAssertTrue(fake.pending.isEmpty)
    }

    func testSyncClearsEverythingWhenNotificationsAreOff() async throws {
        let (model, env, fake) = try makeModel()
        env.store.capture("Call Dana", to: .later, remindAt: env.clock.at(day: 10, hour: 9))
        env.settingsStore.settings.notifications = false

        await model.syncReminders()

        XCTAssertTrue(fake.pending.isEmpty)
    }

    func testDeclinedPermissionTurnsNotificationsOff() async throws {
        let fake = FakeNotifications()
        fake.currentPermission = .notDetermined
        fake.grantsPermission = false
        let (model, env, _) = try makeModel(fake)

        await model.ensureNotificationPermission()

        XCTAssertEqual(fake.requestCount, 1)
        XCTAssertFalse(env.settingsStore.settings.notifications)
    }

    func testAllowedPermissionDoesNotAskAgain() async throws {
        let (model, env, fake) = try makeModel()
        await model.ensureNotificationPermission()
        XCTAssertEqual(fake.requestCount, 0)
        XCTAssertTrue(env.settingsStore.settings.notifications)
    }

    func testTurnOnAfterDenialOpensSettings() async throws {
        let fake = FakeNotifications()
        fake.currentPermission = .denied
        let (model, env, _) = try makeModel(fake)
        env.settingsStore.settings.notifications = false

        await model.turnOnNotifications()

        XCTAssertTrue(fake.openedSystemSettings)
        XCTAssertFalse(env.settingsStore.settings.notifications)
    }

    func testTurnOnWhenAskable() async throws {
        let fake = FakeNotifications()
        fake.currentPermission = .notDetermined
        let (model, env, _) = try makeModel(fake)
        env.settingsStore.settings.notifications = false

        await model.turnOnNotifications()

        XCTAssertTrue(env.settingsStore.settings.notifications)
        XCTAssertEqual(model.toast?.message, "Reminders are on")
    }

    func testDoneFromAlert() async throws {
        let (model, env, fake) = try makeModel()
        let item = try XCTUnwrap(env.store.capture("A", to: .later, remindAt: env.clock.at(day: 10, hour: 9))).item
        await model.syncReminders()
        XCTAssertFalse(fake.pending.isEmpty)

        await model.handleNotificationAction(NotificationAction.done, itemID: item.id)

        XCTAssertTrue(item.isDone)
        XCTAssertTrue(fake.pending.isEmpty, "The nudge is gone before the action returns")
    }

    func testSnoozeFromAlert() async throws {
        let (model, env, _) = try makeModel()
        let item = env.add("A", to: .later)
        let before = item.remindAt
        await model.handleNotificationAction(NotificationAction.snooze, itemID: item.id)
        XCTAssertNotEqual(item.remindAt, before)
        XCTAssertEqual(item.list, .later)
    }

    func testTappingAlertGoesToToday() async throws {
        let (model, env, _) = try makeModel()
        let item = env.add("A", to: .later)
        model.tab = .someday
        await model.handleNotificationAction("com.apple.UNNotificationDefaultActionIdentifier", itemID: item.id)
        XCTAssertEqual(model.tab, .today)
    }
}

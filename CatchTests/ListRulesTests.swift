import XCTest
@testable import Catch

@MainActor
final class ListRulesTests: XCTestCase {
    // MARK: Capture

    func testCaptureTrimsAndIgnoresEmptyText() throws {
        let env = try TestEnvironment()
        XCTAssertNil(env.store.capture("   \n", to: .inbox))
        let result = try XCTUnwrap(env.store.capture("  Buy milk  ", to: .inbox))
        XCTAssertEqual(result.item.text, "Buy milk")
        XCTAssertEqual(env.store.items(in: .inbox).count, 1)
    }

    func testCaptureToFullNowGoesToInbox() throws {
        let env = try TestEnvironment()
        env.add("A", to: .now)
        env.add("B", to: .now)
        env.add("C", to: .now)
        XCTAssertTrue(env.store.isNowFull)

        let result = try XCTUnwrap(env.store.capture("D", to: .now))
        XCTAssertEqual(result.item.list, .inbox)
        XCTAssertTrue(result.redirectedToInbox)
        XCTAssertEqual(env.store.openNowItems.count, 3)
    }

    func testNowLimitFollowsSettings() throws {
        let env = try TestEnvironment()
        env.settingsStore.settings.maxNow = 1
        env.add("A", to: .now)
        XCTAssertTrue(env.store.isNowFull)

        env.settingsStore.settings.maxNow = 2
        XCTAssertFalse(env.store.isNowFull)
    }

    func testDoneAndTomorrowItemsDontCountTowardNowLimit() throws {
        let env = try TestEnvironment()
        let a = env.add("A", to: .now)
        let b = env.add("B", to: .now)
        env.add("C", to: .now)
        env.store.setDone(a, true)
        env.store.moveToTomorrow(b)
        XCTAssertFalse(env.store.isNowFull)
        XCTAssertEqual(env.store.openNowItems.map(\.text), ["C"])
    }

    func testCaptureToLaterDefaultsToAfterWork() throws {
        let env = try TestEnvironment()
        let item = env.add("Pick up dry cleaning", to: .later)
        XCTAssertEqual(item.reminder, .date(env.clock.at(day: 9, hour: 17, minute: 30)))
    }

    func testAfterWorkRollsOverToTomorrowWhenPast() throws {
        let env = try TestEnvironment()
        env.clock.date = env.clock.at(day: 9, hour: 19)
        let item = env.add("Pick up dry cleaning", to: .later)
        XCTAssertEqual(item.reminder, .date(env.clock.at(day: 10, hour: 17, minute: 30)))
    }

    func testCaptureToLaterWithChosenTime() throws {
        let env = try TestEnvironment()
        let time = env.clock.at(day: 10, hour: 10)
        let item = try XCTUnwrap(env.store.capture("Call Dana", to: .later, remindAt: time)).item
        XCTAssertEqual(item.reminder, .date(time))
    }

    // MARK: Moving

    func testMoveIntoNowSetsReasonFromSourceList() throws {
        let env = try TestEnvironment()
        let fromInbox = env.add("Inbox item", to: .inbox)
        let fromLater = env.add("Later item", to: .later)
        let fromSomeday = env.add("Someday item", to: .someday)

        XCTAssertEqual(env.store.move(fromInbox, to: .now), .moved)
        XCTAssertEqual(env.store.move(fromLater, to: .now), .moved)
        XCTAssertEqual(env.store.move(fromSomeday, to: .now), .moved)

        XCTAssertEqual(fromInbox.reason, "Sorted into Now from Inbox")
        XCTAssertEqual(fromLater.reason, "Moved up from Later")
        XCTAssertEqual(fromSomeday.reason, "Pulled in from Someday")
        XCTAssertNil(fromLater.reminder)
    }

    func testMoveIntoFullNowAsksForSwap() throws {
        let env = try TestEnvironment()
        env.add("A", to: .now)
        env.add("B", to: .now)
        env.add("C", to: .now)
        let item = env.add("D", to: .inbox)

        XCTAssertEqual(env.store.move(item, to: .now), .nowIsFull)
        XCTAssertEqual(item.list, .inbox)
    }

    func testMoveToLaterKeepsOrSetsReminder() throws {
        let env = try TestEnvironment()
        let item = env.add("A", to: .now)
        env.store.move(item, to: .later)
        XCTAssertEqual(item.list, .later)
        XCTAssertNil(item.reason)
        XCTAssertNotNil(item.reminder)

        let time = env.clock.at(day: 11, hour: 9)
        let other = env.add("B", to: .inbox)
        env.store.move(other, to: .later, remindAt: time)
        XCTAssertEqual(other.reminder, .date(time))
    }

    func testLeavingLaterClearsReminder() throws {
        let env = try TestEnvironment()
        let item = env.add("A", to: .later)
        env.store.move(item, to: .someday)
        XCTAssertNil(item.reminder)
    }

    func testSwap() throws {
        let env = try TestEnvironment()
        env.add("A", to: .now)
        env.add("B", to: .now)
        let outgoing = env.add("C", to: .now)
        let incoming = env.add("D", to: .someday)

        env.store.swap(incoming: incoming, outgoing: outgoing)

        XCTAssertEqual(outgoing.list, .inbox)
        XCTAssertNil(outgoing.reason)
        XCTAssertEqual(incoming.list, .now)
        XCTAssertEqual(incoming.reason, "Swapped into Now")
        XCTAssertEqual(env.store.openNowItems.count, 3)
    }

    func testSetReminderMovesToLater() throws {
        let env = try TestEnvironment()
        let item = env.add("A", to: .now)
        let time = env.clock.at(day: 9, hour: 15)

        env.store.setReminder(item, .date(time), nudge: false)

        XCTAssertEqual(item.list, .later)
        XCTAssertEqual(item.reminder, .date(time))
        XCTAssertNil(item.reason)
        XCTAssertFalse(env.store.nudges(item))
    }

    func testNudgeFallsBackToSettings() throws {
        let env = try TestEnvironment()
        let item = env.add("A", to: .later)
        XCTAssertTrue(env.store.nudges(item))
        env.settingsStore.settings.nudgeDefault = false
        XCTAssertFalse(env.store.nudges(item))
    }

    func testPlaceReminder() throws {
        let env = try TestEnvironment()
        let office = Place(name: "Office", address: "Halden Studio, Mill St", latitude: 51.5, longitude: -0.1)
        env.store.context.insert(office)
        let item = env.add("Return the keys", to: .inbox)

        env.store.setReminder(item, .place(.leave, office))

        XCTAssertEqual(item.reminder, .place(.leave, office))
        XCTAssertNil(item.remindAt)
    }

    // MARK: Editing

    func testUpdateKeepsTitleWhenEmptyAndDropsEmptyNote() throws {
        let env = try TestEnvironment()
        let item = env.add("Original", to: .inbox)

        env.store.update(item, text: "  ", note: "  ")
        XCTAssertEqual(item.text, "Original")
        XCTAssertNil(item.note)

        env.store.update(item, text: "Renamed", note: " A note ")
        XCTAssertEqual(item.text, "Renamed")
        XCTAssertEqual(item.note, "A note")
    }

    func testDoneCanBeUndone() throws {
        let env = try TestEnvironment()
        let item = env.add("A", to: .now)
        env.store.setDone(item, true)
        XCTAssertTrue(item.isDone)
        env.store.setDone(item, false)
        XCTAssertFalse(item.isDone)
    }

    func testDelete() throws {
        let env = try TestEnvironment()
        let item = env.add("A", to: .inbox)
        env.store.delete(item)
        XCTAssertTrue(env.store.allItems().isEmpty)
    }

    // MARK: Evening wrap-up

    func testAllToTomorrowAndCarryOver() throws {
        let env = try TestEnvironment()
        let done = env.add("Done", to: .now)
        env.add("Left 1", to: .now)
        env.add("Left 2", to: .now)
        env.store.setDone(done, true)

        XCTAssertEqual(env.store.moveAllToTomorrow(), 2)
        XCTAssertTrue(env.store.openNowItems.isEmpty)

        env.store.carryOverFromLastNight()
        let open = env.store.openNowItems
        XCTAssertEqual(open.map(\.text), ["Left 1", "Left 2"])
        XCTAssertEqual(Set(open.compactMap(\.reason)), ["Carried over from last night"])
    }
}

import XCTest
@testable import Catch

@MainActor
final class AppModelTests: XCTestCase {
    private func makeModel() throws -> (AppModel, TestEnvironment) {
        let env = try TestEnvironment()
        env.settingsStore.settings.haptics = false
        return (AppModel(store: env.store, settingsStore: env.settingsStore, notifications: FakeNotifications()), env)
    }

    func testSortingInboxIntoSomeday() throws {
        let (model, env) = try makeModel()
        let item = env.add("Learn pasta", to: .inbox)

        model.move(item, to: .someday)

        XCTAssertEqual(item.list, .someday)
        XCTAssertEqual(model.toast?.message, "Moved to Someday")
        XCTAssertEqual(model.toast?.canUndo, true)
    }

    func testSortingIntoFullNowLeavesItemInInbox() throws {
        let (model, env) = try makeModel()
        env.add("A", to: .now)
        env.add("B", to: .now)
        env.add("C", to: .now)
        let item = env.add("D", to: .inbox)

        model.move(item, to: .now)

        XCTAssertEqual(item.list, .inbox)
        guard case .swap(let incoming)? = model.sheet else { return XCTFail("Expected the Swap sheet") }
        XCTAssertEqual(incoming, item)
    }

    func testSwapFromSheet() throws {
        let (model, env) = try makeModel()
        env.add("A", to: .now)
        env.add("B", to: .now)
        let outgoing = env.add("C", to: .now)
        let incoming = env.add("D", to: .inbox)
        model.move(incoming, to: .now)

        model.swap(incoming: incoming, outgoing: outgoing)

        XCTAssertNil(model.sheet)
        XCTAssertEqual(incoming.list, .now)
        XCTAssertEqual(outgoing.list, .inbox)
        XCTAssertEqual(model.toast?.message, "Swapped. “C” went to Inbox")
        model.undo()
        XCTAssertEqual(incoming.list, .inbox)
        XCTAssertEqual(outgoing.list, .now)
    }

    func testLaterOpensRemindSheet() throws {
        let (model, env) = try makeModel()
        let item = env.add("Dentist", to: .inbox)

        model.move(item, to: .later)

        XCTAssertEqual(item.list, .inbox, "Nothing moves until a time is chosen")
        guard case .remind(let target)? = model.sheet else { return XCTFail("Expected the Remind sheet") }
        XCTAssertEqual(target, item)
    }

    func testSetReminderFromSheet() throws {
        let (model, env) = try makeModel()
        let item = env.add("Dentist", to: .now)
        let time = env.clock.at(day: 10, hour: 9)
        model.openReminder(for: item)

        model.setReminder(item, .date(time), nudge: false, label: "tomorrow morning")

        XCTAssertNil(model.sheet)
        XCTAssertEqual(item.list, .later)
        XCTAssertEqual(item.remindAt, time)
        XCTAssertEqual(item.nudge, false)
        XCTAssertEqual(model.toast?.message, "Reminder set: tomorrow morning")
    }

    func testMoveToNowFromSomeday() throws {
        let (model, env) = try makeModel()
        let item = env.add("Herb garden", to: .someday)

        model.move(item, to: .now)

        XCTAssertEqual(item.list, .now)
        XCTAssertEqual(item.reason, "Pulled in from Someday")
        XCTAssertEqual(model.toast?.message, "Moved to Now")
    }

    func testDeleteCanBeUndone() throws {
        let (model, env) = try makeModel()
        let item = env.add("Gym plan", to: .inbox)

        model.delete(item)
        XCTAssertEqual(model.toast?.message, "Deleted")
        XCTAssertTrue(env.store.allItems().isEmpty)

        model.undo()
        XCTAssertEqual(env.store.items(in: .inbox).map(\.text), ["Gym plan"])
    }

    func testToastUndoOnlyReversesWhatItDescribes() throws {
        let (model, env) = try makeModel()
        let captured = env.add("X", to: .inbox)
        model.move(captured, to: .someday)
        XCTAssertEqual(model.toast?.message, "Moved to Someday")
        // Something else records an undo without a toast of its own.
        let other = env.add("Y", to: .inbox)
        env.store.update(other, text: "Y edited", note: nil)

        model.undo()

        XCTAssertEqual(captured.list, .someday, "The toast's action was replaced; Undo does nothing")
        XCTAssertEqual(other.text, "Y edited")
        XCTAssertNil(model.toast)
    }

    func testUndoClosesAnOpenSheet() throws {
        let (model, env) = try makeModel()
        let item = env.add("X", to: .inbox)
        model.move(item, to: .someday)
        model.openEditor(for: item)

        model.undo()

        XCTAssertNil(model.sheet)
        XCTAssertEqual(item.list, .inbox)
    }

    func testPinnedBarHiddenUnderSheets() throws {
        let (model, env) = try makeModel()
        model.tab = .inbox
        XCTAssertTrue(model.showsPinnedUpFirst)
        model.isCaptureOpen = true
        XCTAssertFalse(model.showsPinnedUpFirst)
        model.isCaptureOpen = false
        model.openReminder(for: env.add("A", to: .inbox))
        XCTAssertFalse(model.showsPinnedUpFirst)
    }
}

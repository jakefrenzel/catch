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

    func testSwipingAToastAwayDismissesIt() throws {
        let (model, env) = try makeModel()
        model.move(env.add("Learn pasta", to: .inbox), to: .someday)
        XCTAssertNotNil(model.toast)

        model.dismissToast()
        XCTAssertNil(model.toast)
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

    func testUndoingACaptureClosesFocusOnIt() throws {
        let (model, env) = try makeModel()
        XCTAssertTrue(model.capture("Call Bob", to: .now))
        let item = try XCTUnwrap(env.store.items(in: .now).first)
        model.startFocus(on: .item(item))

        model.undo()

        XCTAssertTrue(env.store.allItems().isEmpty)
        XCTAssertNil(model.focus)
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

    func testSwipingThePinnedBarHidesItUntilUpFirstChanges() throws {
        let (model, env) = try makeModel()
        let first = UUID(), second = UUID()
        model.tab = .inbox
        model.currentUpFirst = first
        model.hidePinnedUpFirst()
        XCTAssertFalse(model.showsPinnedUpFirst)
        model.tab = .someday
        XCTAssertFalse(model.showsPinnedUpFirst, "Stays hidden on other tabs")

        model.appMovedToBackground()
        XCTAssertFalse(model.showsPinnedUpFirst, "Stays hidden after leaving the app")
        let relaunched = AppModel(store: env.store, settingsStore: env.settingsStore, notifications: FakeNotifications())
        relaunched.tab = .inbox
        relaunched.currentUpFirst = first
        XCTAssertFalse(relaunched.showsPinnedUpFirst, "Stays hidden after a relaunch")

        model.currentUpFirst = second
        XCTAssertTrue(model.showsPinnedUpFirst, "Back for a new suggestion")
        model.currentUpFirst = first
        XCTAssertTrue(model.showsPinnedUpFirst, "And stays back if the first one returns")
    }

    func testStartingFocusOutOfOrderSaysWhereItsFrom() throws {
        let (model, env) = try makeModel()
        let first = env.add("Call Bob", to: .now)
        let chosen = env.add("Pay rent", to: .later)
        let candidates: [UpFirstCandidate] = [.item(first), .item(chosen)]

        model.startChosenFocus(.item(chosen))
        XCTAssertEqual(model.focus, .item(chosen))
        XCTAssertEqual(model.focusReason(for: .item(chosen)), "From Later")

        model.skipFocus(in: candidates)
        XCTAssertNil(model.focus)
        XCTAssertTrue(model.upFirst.skipped.isEmpty, "Not Now on a chosen item leaves Up first alone")
    }

    func testUpFirstStartStillSkipsOnNotNow() throws {
        let (model, env) = try makeModel()
        let first = env.add("Call Bob", to: .now)
        let second = env.add("Pay rent", to: .now)
        let candidates: [UpFirstCandidate] = [.item(first), .item(second)]

        model.startFocus(on: .item(first))
        XCTAssertEqual(model.focusReason(for: .item(first)), UpFirstCandidate.item(first).reason)

        model.skipFocus(in: candidates)
        XCTAssertEqual(model.upFirst.skipped, [first.id])
    }

    func testStartFocusFromTheEditSheetKeepsTheEdits() async throws {
        let (model, env) = try makeModel()
        let item = env.add("Draft", to: .someday)
        model.openEditor(for: item)

        model.saveEditAndFocus(item, text: "Draft the intro", note: nil, list: .someday)

        XCTAssertNil(model.sheet)
        XCTAssertEqual(item.text, "Draft the intro")
        try await Task.sleep(for: .milliseconds(600))
        XCTAssertEqual(model.focus, .item(item))
        XCTAssertEqual(model.focusReason(for: .item(item)), "From Someday")
    }

    func testListsGiveBackTheBarsRoomWhenItsHidden() throws {
        let (model, env) = try makeModel()
        model.tab = .inbox
        model.currentUpFirst = UUID()
        let withBar = model.listBottomMargin

        model.hidePinnedUpFirst()
        XCTAssertLessThan(model.listBottomMargin, withBar, "Swiped away")

        model.currentUpFirst = UUID()
        XCTAssertEqual(model.listBottomMargin, withBar)

        model.currentUpFirst = nil
        XCTAssertLessThan(model.listBottomMargin, withBar, "Nothing up first")
        model.currentUpFirst = UUID()

        env.settingsStore.settings.pinnedUpFirst = false
        XCTAssertLessThan(model.listBottomMargin, withBar, "Turned off in Settings")
    }

    func testPinnedBarSettingTurnsItOff() throws {
        let (model, env) = try makeModel()
        model.tab = .inbox
        env.settingsStore.settings.pinnedUpFirst = false
        XCTAssertFalse(model.showsPinnedUpFirst)
    }
}

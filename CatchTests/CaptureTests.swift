import XCTest
@testable import Catch

final class QuickTimesTests: XCTestCase {
    private let clock = TestClock()

    private func options(day: Int, hour: Int) -> [QuickTime] {
        QuickTimes.options(now: clock.at(day: day, hour: hour), calendar: clock.calendar)
    }

    func testFridayMidday() {
        // October 9, 2026 is a Friday.
        XCTAssertEqual(options(day: 9, hour: 12), [
            QuickTime(kind: .tonight, date: clock.at(day: 9, hour: 19)),
            QuickTime(kind: .tomorrow, date: clock.at(day: 10, hour: 9)),
            QuickTime(kind: .weekend, date: clock.at(day: 10, hour: 10)),
        ])
    }

    func testTonightDisappearsAfterSeven() {
        XCTAssertEqual(options(day: 9, hour: 20).map(\.kind), [.tomorrow, .weekend])
        XCTAssertEqual(options(day: 9, hour: 19).map(\.kind), [.tomorrow, .weekend])
    }

    func testWeekendIsTheNextSaturdayMorning() {
        XCTAssertEqual(options(day: 10, hour: 8).last?.date, clock.at(day: 10, hour: 10))
        XCTAssertEqual(options(day: 10, hour: 11).last?.date, clock.at(day: 17, hour: 10))
        XCTAssertEqual(options(day: 11, hour: 9).last?.date, clock.at(day: 17, hour: 10))
    }

    func testChipDetails() {
        let formatter = ReminderFormatter(calendar: clock.calendar, locale: Locale(identifier: "en_US"))
        let details = options(day: 9, hour: 12).map {
            formatter.detail(for: $0)
                .replacingOccurrences(of: "\u{202F}", with: " ")
                .replacingOccurrences(of: "\u{00A0}", with: " ")
        }
        XCTAssertEqual(details, ["7 PM", "9 AM", "Sat 10 AM"])
    }
}

@MainActor
final class CaptureMessageTests: XCTestCase {
    private func makeModel() throws -> (AppModel, TestEnvironment) {
        let env = try TestEnvironment()
        env.settingsStore.settings.haptics = false
        return (AppModel(store: env.store, settingsStore: env.settingsStore), env)
    }

    func testSavedToast() throws {
        let (model, _) = try makeModel()
        XCTAssertTrue(model.capture("Buy milk", to: .someday))
        XCTAssertEqual(model.toast?.message, "Saved to Someday")
        XCTAssertEqual(model.toast?.canUndo, true)
    }

    func testFullNowToast() throws {
        let (model, env) = try makeModel()
        env.add("A", to: .now)
        env.add("B", to: .now)
        env.add("C", to: .now)

        XCTAssertTrue(model.capture("D", to: .now))

        XCTAssertEqual(model.toast?.message, "Now is full. Saved to Inbox")
        XCTAssertEqual(env.store.items(in: .inbox).map(\.text), ["D"])
    }

    func testEmptyTextSavesNothing() throws {
        let (model, env) = try makeModel()
        XCTAssertFalse(model.capture("   ", to: .inbox))
        XCTAssertNil(model.toast)
        XCTAssertTrue(env.store.allItems().isEmpty)
    }

    func testUndoFromToastRemovesTheCapture() throws {
        let (model, env) = try makeModel()
        model.capture("Oops", to: .inbox)
        model.undo()
        XCTAssertNil(model.toast)
        XCTAssertTrue(env.store.allItems().isEmpty)
    }

    func testLaterUsesChosenTime() throws {
        let (model, env) = try makeModel()
        let time = env.clock.at(day: 10, hour: 9)
        model.capture("Call Dana", to: .later, remindAt: time)
        XCTAssertEqual(env.store.items(in: .later).first?.remindAt, time)
    }
}

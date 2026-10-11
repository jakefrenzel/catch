import XCTest
@testable import Catch

final class ReminderFormatterTests: XCTestCase {
    private let clock = TestClock()

    private var formatter: ReminderFormatter {
        ReminderFormatter(calendar: clock.calendar, locale: Locale(identifier: "en_US"))
    }

    /// Newer ICU puts a narrow no-break space before AM/PM.
    private func label(_ date: Date) -> String {
        formatter.label(for: date, now: clock.at(day: 9, hour: 12))
            .replacingOccurrences(of: "\u{202F}", with: " ")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    func testSameDayShowsTimeOnly() {
        XCTAssertEqual(label(clock.at(day: 9, hour: 17, minute: 30)), "5:30 PM")
        XCTAssertEqual(label(clock.at(day: 9, hour: 20)), "8 PM")
    }

    func testThisWeekShowsWeekday() {
        // October 9, 2026 is a Friday.
        XCTAssertEqual(label(clock.at(day: 10, hour: 9)), "Sat 9 AM")
        XCTAssertEqual(label(clock.at(day: 12, hour: 9, minute: 15)), "Mon 9:15 AM")
    }

    func testFurtherOutShowsDate() {
        XCTAssertEqual(label(clock.at(day: 20, hour: 9)), "Oct 20 9 AM")
    }

    @MainActor
    func testPlaceLabels() throws {
        let env = try TestEnvironment()
        let office = Place(name: "Office", address: "", latitude: 0, longitude: 0)
        env.store.context.insert(office)
        let now = clock.at(day: 9, hour: 12)
        XCTAssertEqual(formatter.label(for: .place(.leave, office), now: now), "Leaving Office")
        XCTAssertEqual(formatter.label(for: .place(.arrive, office), now: now), "Arriving Office")
    }
}

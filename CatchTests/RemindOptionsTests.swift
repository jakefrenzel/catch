import XCTest
@testable import Catch

final class RemindOptionsTests: XCTestCase {
    private let clock = TestClock()
    private let afterWork = TimeOfDay(hour: 17, minute: 30)

    private func options(day: Int, hour: Int, places: [Place] = []) -> [RemindOption] {
        RemindOptions.options(now: clock.at(day: day, hour: hour), calendar: clock.calendar,
                              afterWork: afterWork, places: places)
    }

    func testMorningOffersEverything() {
        let result = options(day: 9, hour: 10)
        XCTAssertEqual(result.map(\.title), ["This afternoon", "After work", "Tonight", "Tomorrow morning"])
        XCTAssertEqual(result.map(\.date), [
            clock.at(day: 9, hour: 15),
            clock.at(day: 9, hour: 17, minute: 30),
            clock.at(day: 9, hour: 20),
            clock.at(day: 10, hour: 9),
        ])
    }

    func testPassedTimesDropOutAndAfterWorkMovesToTomorrow() {
        XCTAssertEqual(options(day: 9, hour: 16).map(\.kind), [.afterWork, .tonight, .tomorrowMorning])
        let late = options(day: 9, hour: 21)
        XCTAssertEqual(late.map(\.kind), [.afterWork, .tomorrowMorning])
        XCTAssertEqual(late.first?.date, clock.at(day: 10, hour: 17, minute: 30))
    }

    func testTomorrowAfterMidnightIsTheComingMorning() {
        // 1 AM is still last night by the Catch day, so tomorrow morning is in 8 hours, not 32.
        let tomorrow = options(day: 10, hour: 1).first { $0.kind == .tomorrowMorning }
        XCTAssertEqual(tomorrow?.date, clock.at(day: 10, hour: 9))
    }

    @MainActor
    func testPlacesAppearBeforeTomorrow() throws {
        let env = try TestEnvironment()
        let office = Place(name: "Office", address: "Halden Studio, Mill St", latitude: 0, longitude: 0)
        env.store.context.insert(office)

        let result = options(day: 9, hour: 21, places: [office])

        XCTAssertEqual(result.map(\.title),
                       ["After work", "When I leave Office", "When I get to Office", "Tomorrow morning"])
        XCTAssertEqual(result[1].reminder, .place(.leave, office))
        XCTAssertEqual(result[2].reminder, .place(.arrive, office))
    }

    @MainActor
    func testSettingsChooseWhichPlaceOptionsShow() throws {
        let env = try TestEnvironment()
        let office = Place(name: "Office", address: "", latitude: 0, longitude: 0)
        env.store.context.insert(office)

        let leaveOnly = RemindOptions.options(now: clock.at(day: 9, hour: 21), calendar: clock.calendar,
                                              afterWork: afterWork, places: [office],
                                              offerLeave: true, offerArrive: false)
        XCTAssertEqual(leaveOnly.map(\.title), ["After work", "When I leave Office", "Tomorrow morning"])
    }

    @MainActor
    func testAnItemsOwnPlaceReminderStaysOfferedWhenTurnedOff() throws {
        let env = try TestEnvironment()
        let office = Place(name: "Office", address: "", latitude: 0, longitude: 0)
        env.store.context.insert(office)

        let result = RemindOptions.options(now: clock.at(day: 9, hour: 21), calendar: clock.calendar,
                                           afterWork: afterWork, places: [office],
                                           offerLeave: false, offerArrive: false,
                                           keeping: .place(.leave, office))
        XCTAssertEqual(result.map(\.title), ["After work", "When I leave Office", "Tomorrow morning"])
        XCTAssertEqual(result[1].reminder, .place(.leave, office))
    }

    func testPickerDaysStartToday() {
        let days = RemindOptions.pickerDays(now: clock.at(day: 9, hour: 15), calendar: clock.calendar)
        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(days.first, clock.at(day: 9, hour: 0))
        XCTAssertEqual(days.last, clock.at(day: 15, hour: 0))
    }

    func testCombineDayAndTime() {
        let combined = RemindOptions.combine(day: clock.at(day: 12, hour: 0),
                                             time: clock.at(day: 9, hour: 9, minute: 45),
                                             calendar: clock.calendar)
        XCTAssertEqual(combined, clock.at(day: 12, hour: 9, minute: 45))
    }

    func testRoundsUpToQuarterHour() {
        let calendar = clock.calendar
        XCTAssertEqual(RemindOptions.roundedToQuarterHour(clock.at(day: 9, hour: 9, minute: 7), calendar: calendar),
                       clock.at(day: 9, hour: 9, minute: 15))
        XCTAssertEqual(RemindOptions.roundedToQuarterHour(clock.at(day: 9, hour: 9, minute: 45), calendar: calendar),
                       clock.at(day: 9, hour: 9, minute: 45))
        XCTAssertEqual(RemindOptions.roundedToQuarterHour(clock.at(day: 9, hour: 9, minute: 50), calendar: calendar),
                       clock.at(day: 9, hour: 10))
    }

    func testLongLabel() {
        let formatter = ReminderFormatter(calendar: clock.calendar, locale: Locale(identifier: "en_US"))
        let label = formatter.longLabel(for: clock.at(day: 10, hour: 9))
            .replacingOccurrences(of: "\u{202F}", with: " ")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
        XCTAssertEqual(label, "Saturday, October 10 at 9:00 AM")
    }
}

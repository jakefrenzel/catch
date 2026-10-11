import XCTest
@testable import Catch

final class SettingsTests: XCTestCase {
    func testSettingsMoveToTheSharedStoreOnce() throws {
        let legacy = try XCTUnwrap(UserDefaults(suiteName: "catch-tests-legacy-\(UUID().uuidString)"))
        let shared = try XCTUnwrap(UserDefaults(suiteName: "catch-tests-shared-\(UUID().uuidString)"))
        let old = SettingsStore(defaults: legacy)
        old.settings.maxNow = 5
        old.hasOnboarded = true

        let moved = SettingsStore(defaults: shared, migratingFrom: legacy)

        XCTAssertEqual(moved.settings.maxNow, 5)
        XCTAssertTrue(moved.hasOnboarded)
        // Later changes in the shared store aren't overwritten by the old copy.
        moved.settings.maxNow = 4
        XCTAssertEqual(SettingsStore(defaults: shared, migratingFrom: legacy).settings.maxNow, 4)
    }

    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "test-\(UUID().uuidString)")!
    }

    func testDefaults() {
        let settings = CatchSettings()
        XCTAssertEqual(settings.maxNow, 3)
        XCTAssertEqual(settings.afterWork, TimeOfDay(hour: 17, minute: 30))
        XCTAssertEqual(settings.wrapUpTime, TimeOfDay(hour: 21, minute: 0))
        XCTAssertEqual(settings.wrapUpStyle, .onToday)
        XCTAssertEqual(settings.appearance, .system)
        XCTAssertTrue(settings.notifications)
        XCTAssertTrue(settings.nudgeDefault)
        XCTAssertTrue(settings.upFirstIncludesSteps)
        XCTAssertTrue(settings.haptics)
    }

    func testMaxNowIsClamped() {
        var settings = CatchSettings()
        settings.maxNow = 9
        XCTAssertEqual(settings.maxNow, 5)
        settings.maxNow = 0
        XCTAssertEqual(settings.maxNow, 1)
    }

    func testStorePersistsChanges() {
        let defaults = freshDefaults()
        let store = SettingsStore(defaults: defaults)
        store.settings.maxNow = 4
        store.settings.appearance = .dark
        store.settings.afterWork = TimeOfDay(hour: 18, minute: 0)

        let reloaded = SettingsStore(defaults: defaults).settings
        XCTAssertEqual(reloaded.maxNow, 4)
        XCTAssertEqual(reloaded.appearance, .dark)
        XCTAssertEqual(reloaded.afterWork, TimeOfDay(hour: 18, minute: 0))
    }

    func testDecodingFillsMissingAndInvalidKeysWithDefaults() throws {
        let json = #"{"maxNow": 7, "haptics": false, "appearance": "sepia"}"#
        let settings = try JSONDecoder().decode(CatchSettings.self, from: Data(json.utf8))
        XCTAssertEqual(settings.maxNow, 5)
        XCTAssertFalse(settings.haptics)
        XCTAssertEqual(settings.appearance, .system)
        XCTAssertTrue(settings.notifications)
    }

    func testTimeOfDayNextOccurrence() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let noon = calendar.date(from: DateComponents(year: 2026, month: 10, day: 9, hour: 12))!
        let evening = calendar.date(from: DateComponents(year: 2026, month: 10, day: 9, hour: 21))!

        let afterWork = TimeOfDay(hour: 17, minute: 30)
        XCTAssertEqual(afterWork.next(after: noon, calendar: calendar),
                       calendar.date(from: DateComponents(year: 2026, month: 10, day: 9, hour: 17, minute: 30)))
        XCTAssertEqual(afterWork.next(after: evening, calendar: calendar),
                       calendar.date(from: DateComponents(year: 2026, month: 10, day: 10, hour: 17, minute: 30)))
    }
}

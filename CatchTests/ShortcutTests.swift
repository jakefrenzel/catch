import XCTest
@testable import Catch

@MainActor
final class ShortcutTests: XCTestCase {
    private let formatter = ReminderFormatter(locale: Locale(identifier: "en_US"))

    func testCatchThoughtGoesToInbox() throws {
        let env = try TestEnvironment()
        let saved = try XCTUnwrap(ShortcutActions.catchThought("buy milk", store: env.store))
        XCTAssertEqual(saved.title, "Buy milk")
        XCTAssertEqual(saved.destination, "Inbox")
        XCTAssertEqual(env.store.items(in: .inbox).map(\.text), ["Buy milk"])
    }

    func testCatchThoughtWithATimeGoesToLater() throws {
        let env = try TestEnvironment()
        let saved = try XCTUnwrap(ShortcutActions.catchThought("call Dana tomorrow at 10 about the lease",
                                                               store: env.store, formatter: formatter))
        XCTAssertEqual(saved.title, "Call Dana about the lease")
        XCTAssertTrue(saved.destination.hasPrefix("Later · "))
        XCTAssertEqual(env.store.items(in: .later).count, 1)
    }

    func testCatchThoughtIgnoresProjects() throws {
        let env = try TestEnvironment()
        env.addProject("Kitchen Reno", steps: [("Measure", "Plan")])
        let saved = try XCTUnwrap(ShortcutActions.catchThought("tile quote for the kitchen reno", store: env.store))
        XCTAssertEqual(saved.destination, "Inbox")
    }

    func testEmptyThoughtSavesNothing() throws {
        let env = try TestEnvironment()
        XCTAssertNil(ShortcutActions.catchThought("  ", store: env.store))
    }

    func testAddToNowAndFull() throws {
        let env = try TestEnvironment()
        XCTAssertEqual(ShortcutActions.addToNow("A", store: env.store)?.destination, "Now")
        env.add("B", to: .now)
        env.add("C", to: .now)
        XCTAssertEqual(ShortcutActions.addToNow("D", store: env.store)?.destination, "Inbox (Now is full)")
    }

    func testUpFirstAndNowList() throws {
        let env = try TestEnvironment()
        XCTAssertEqual(ShortcutActions.upFirst(store: env.store), "Nothing's up first. Today is clear.")
        XCTAssertEqual(ShortcutActions.nowList(store: env.store), "Nothing in Now.")

        env.add("Send invoice", to: .now)
        env.add("Call Dana", to: .now)
        env.add("Buy milk", to: .now)

        XCTAssertEqual(ShortcutActions.upFirst(store: env.store), "Up first: Send invoice. You just added it to Now.")
        XCTAssertEqual(ShortcutActions.nowList(store: env.store), "In Now: Send invoice, Call Dana and Buy milk.")
    }

    func testWrapUp() throws {
        let env = try TestEnvironment()
        env.add("A", to: .now)
        env.add("B", to: .now)

        XCTAssertEqual(ShortcutActions.wrapUp(store: env.store, settingsStore: env.settingsStore),
                       "Day finished. Moved 2 things to tomorrow.")
        XCTAssertTrue(env.store.openNowItems.isEmpty)
        XCTAssertNotNil(env.settingsStore.dayFinishedOn)
    }
}

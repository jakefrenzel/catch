import XCTest
@testable import Catch

@MainActor
final class AppModelTests: XCTestCase {
    private func makeModel() throws -> (AppModel, TestEnvironment) {
        let env = try TestEnvironment()
        env.settingsStore.settings.haptics = false
        return (AppModel(store: env.store, settingsStore: env.settingsStore), env)
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
        XCTAssertEqual(model.toast?.message, "Now is full (3). Move something out first")
        XCTAssertEqual(model.toast?.canUndo, false)
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

    func testPinnedBarHiddenWhileCapturing() throws {
        let (model, _) = try makeModel()
        model.tab = .inbox
        XCTAssertTrue(model.showsPinnedUpFirst)
        model.isCaptureOpen = true
        XCTAssertFalse(model.showsPinnedUpFirst)
    }
}

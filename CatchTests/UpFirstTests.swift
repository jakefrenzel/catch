import XCTest
@testable import Catch

@MainActor
final class UpFirstTests: XCTestCase {
    func testNowItemsComeBeforeProjectSteps() throws {
        let env = try TestEnvironment()
        env.addProject("Kitchen Reno", steps: [("Measure the wall", "Plan")])
        env.add("Send invoice", to: .now)
        env.add("Call Dana", to: .now)

        let titles = env.store.upFirstCandidates().map(\.title)
        XCTAssertEqual(titles, ["Send invoice", "Call Dana", "Measure the wall"])
    }

    func testSkipsDoneAndMovedToTomorrowItems() throws {
        let env = try TestEnvironment()
        let done = env.add("Done already", to: .now)
        let tomorrow = env.add("Tomorrow", to: .now)
        env.add("Still open", to: .now)
        env.add("Not in Now", to: .inbox)
        env.store.setDone(done, true)
        env.store.moveToTomorrow(tomorrow)

        XCTAssertEqual(env.store.upFirstCandidates().map(\.title), ["Still open"])
    }

    func testProjectStepsOnlyWhenSettingIsOn() throws {
        let env = try TestEnvironment()
        env.addProject("Lisbon Trip", steps: [("Book flights", "Book")])
        env.settingsStore.settings.upFirstIncludesSteps = false

        XCTAssertTrue(env.store.upFirstCandidates().isEmpty)
    }

    func testOffersEachProjectsFirstUnfinishedStepInProjectOrder() throws {
        let env = try TestEnvironment()
        let reno = env.addProject("Kitchen Reno", steps: [("Measure", "Plan"), ("Order samples", "Choose")])
        env.addProject("Lisbon Trip", steps: [("Renew passport", "Prepare")])
        env.store.setDone(reno.orderedSteps[0], true)

        let candidates = env.store.upFirstCandidates()
        XCTAssertEqual(candidates.map(\.title), ["Order samples", "Renew passport"])
        XCTAssertEqual(candidates.map(\.reason), ["Next step in Kitchen Reno", "Next step in Lisbon Trip"])
    }

    func testReasons() throws {
        let env = try TestEnvironment()
        let added = env.add("Added", to: .now)
        added.reason = nil
        env.add("Fresh", to: .now)

        let reasons = env.store.upFirstCandidates().map(\.reason)
        XCTAssertEqual(reasons, ["First open item in Now", "You just added it to Now"])
    }

    func testSkipMovesToNextAndResetsWhenAllSkipped() throws {
        let env = try TestEnvironment()
        env.add("A", to: .now)
        env.add("B", to: .now)
        env.add("C", to: .now)
        let candidates = env.store.upFirstCandidates()
        var upFirst = UpFirst()

        XCTAssertEqual(upFirst.current(in: candidates)?.title, "A")
        upFirst.skip(in: candidates)
        XCTAssertEqual(upFirst.current(in: candidates)?.title, "B")
        upFirst.skip(in: candidates)
        XCTAssertEqual(upFirst.current(in: candidates)?.title, "C")
        upFirst.skip(in: candidates)
        XCTAssertTrue(upFirst.skipped.isEmpty)
        XCTAssertEqual(upFirst.current(in: candidates)?.title, "A")
    }

    func testCompletingMovesOnToTheNextCandidate() throws {
        let env = try TestEnvironment()
        env.add("A", to: .now)
        env.addProject("Reno", steps: [("Measure", "Plan"), ("Budget", "Plan")])
        let upFirst = UpFirst()

        env.store.complete(try XCTUnwrap(upFirst.current(in: env.store.upFirstCandidates())))
        XCTAssertEqual(upFirst.current(in: env.store.upFirstCandidates())?.title, "Measure")

        env.store.complete(try XCTUnwrap(upFirst.current(in: env.store.upFirstCandidates())))
        XCTAssertEqual(upFirst.current(in: env.store.upFirstCandidates())?.title, "Budget")
    }

    func testNothingToSuggest() {
        var upFirst = UpFirst()
        XCTAssertNil(upFirst.current(in: []))
        upFirst.skip(in: [])
        XCTAssertTrue(upFirst.skipped.isEmpty)
    }
}

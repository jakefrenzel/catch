import XCTest
@testable import Catch

@MainActor
final class ProjectTests: XCTestCase {
    func testPhasesProgressAndNextStep() throws {
        let env = try TestEnvironment()
        let reno = env.addProject("Kitchen Reno", steps: [
            ("Measure the wall", "Plan"), ("Set a budget", "Plan"),
            ("Order cabinet samples", "Choose"), ("Pick countertop", "Choose"),
            ("Get 3 contractor quotes", "Build"),
        ])
        env.store.setDone(reno.orderedSteps[0], true)
        env.store.setDone(reno.orderedSteps[1], true)

        XCTAssertEqual(reno.phases.map(\.name), ["Plan", "Choose", "Build"])
        XCTAssertEqual(reno.phases.map(\.isDone), [true, false, false])
        XCTAssertEqual(reno.currentPhaseIndex, 1)
        XCTAssertEqual(reno.nextStep?.text, "Order cabinet samples")
        XCTAssertEqual(reno.doneCount, 2)
        XCTAssertEqual(reno.progress, 0.4, accuracy: 0.0001)
    }

    func testAllDone() throws {
        let env = try TestEnvironment()
        let trip = env.addProject("Trip", steps: [("Book", "Book")])
        env.store.setDone(trip.orderedSteps[0], true)
        XCTAssertNil(trip.currentPhaseIndex)
        XCTAssertNil(trip.nextStep)
        XCTAssertEqual(trip.progress, 1)
    }

    // MARK: Creating

    func testCreateRequiresName() throws {
        let env = try TestEnvironment()
        XCTAssertNil(env.store.createProject(from: ProjectDraft(name: "   ")))
        XCTAssertTrue(env.store.projects().isEmpty)
    }

    func testCreateWithoutStepsGetsPlaceholder() throws {
        let env = try TestEnvironment()
        let project = try XCTUnwrap(env.store.createProject(from: ProjectDraft(name: " Garden ")))
        XCTAssertEqual(project.name, "Garden")
        XCTAssertEqual(project.orderedSteps.map(\.text), ["Decide the first step"])
        XCTAssertEqual(project.orderedSteps.map(\.phase), ["Steps"])
    }

    func testNewProjectsGoToTheEnd() throws {
        let env = try TestEnvironment()
        env.store.createProject(from: ProjectDraft(name: "First"))
        env.store.createProject(from: ProjectDraft(name: "Second"))
        XCTAssertEqual(env.store.projects().map(\.name), ["First", "Second"])
    }

    func testCreateConsumesInboxItems() throws {
        let env = try TestEnvironment()
        let used = env.add("Renew passport", to: .inbox)
        env.add("Unrelated", to: .inbox)
        let draft = ProjectDraft(name: "Lisbon", rows: [.step("Book flights"), .step(used.text, fromInbox: used)])

        let project = try XCTUnwrap(env.store.createProject(from: draft))

        XCTAssertEqual(project.orderedSteps.map(\.text), ["Book flights", "Renew passport"])
        XCTAssertEqual(env.store.items(in: .inbox).map(\.text), ["Unrelated"])
    }

    // MARK: Draft

    func testDraftResolvesPhases() {
        let draft = ProjectDraft(name: "Reno", rows: [
            .step("Before any phase"),
            .phase("Plan"), .step("Measure"), .step("  "),
            .phase(""), .step("Build it"),
        ])
        XCTAssertEqual(draft.resolvedSteps(), [
            .init(text: "Before any phase", phase: "Steps"),
            .init(text: "Measure", phase: "Plan"),
            .init(text: "Build it", phase: "Phase 5"),
        ])
    }

    func testDraftSuggestsPhaseNames() {
        var draft = ProjectDraft()
        draft.addPhase()
        draft.addPhase()
        draft.addPhase()
        draft.addPhase()
        XCTAssertEqual(draft.rows, [.phase("Plan"), .phase("Do"), .phase("Finish"), .phase("Phase 4")])
    }

    // MARK: Adding steps

    func testAddStepGoesAtEndOfCurrentPhase() throws {
        let env = try TestEnvironment()
        let reno = env.addProject("Reno", steps: [
            ("Measure", "Plan"), ("Order samples", "Choose"), ("Get quotes", "Build"),
        ])
        env.store.setDone(reno.orderedSteps[0], true)

        let step = try XCTUnwrap(env.store.addStep(" Pick countertop ", to: reno))

        XCTAssertEqual(step.phase, "Choose")
        XCTAssertEqual(reno.orderedSteps.map(\.text), ["Measure", "Order samples", "Pick countertop", "Get quotes"])
    }

    func testAddStepWhenAllDoneUsesLastPhase() throws {
        let env = try TestEnvironment()
        let trip = env.addProject("Trip", steps: [("Book", "Book"), ("Pack", "Prepare")])
        trip.orderedSteps.forEach { env.store.setDone($0, true) }

        let step = try XCTUnwrap(env.store.addStep("Check in", to: trip))

        XCTAssertEqual(step.phase, "Prepare")
        XCTAssertEqual(trip.orderedSteps.last?.text, "Check in")
        XCTAssertEqual(trip.nextStep?.text, "Check in")
    }

    func testAddStepIgnoresEmptyText() throws {
        let env = try TestEnvironment()
        let trip = env.addProject("Trip", steps: [("Book", "Book")])
        XCTAssertNil(env.store.addStep("  ", to: trip))
        XCTAssertEqual(trip.orderedSteps.count, 1)
    }
}

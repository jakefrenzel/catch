import XCTest
@testable import Catch

@MainActor
final class ProjectFlowTests: XCTestCase {
    private func makeModel() throws -> (AppModel, TestEnvironment) {
        let env = try TestEnvironment()
        env.settingsStore.settings.haptics = false
        return (AppModel(store: env.store, settingsStore: env.settingsStore), env)
    }

    func testCreateWithoutNameAsksForOne() throws {
        let (model, env) = try makeModel()
        model.openNewProject()

        XCTAssertFalse(model.createProject(from: ProjectDraft(name: "  ")))

        XCTAssertEqual(model.toast?.message, "Give the project a name")
        guard case .newProject? = model.sheet else { return XCTFail("The sheet should stay open") }
        XCTAssertTrue(env.store.projects().isEmpty)
    }

    func testCreateOpensTheProject() throws {
        let (model, env) = try makeModel()
        model.tab = .inbox
        model.openNewProject()

        XCTAssertTrue(model.createProject(from: ProjectDraft(name: "Garden", rows: [.step("Buy seeds")])))

        let project = try XCTUnwrap(env.store.projects().first)
        XCTAssertNil(model.sheet)
        XCTAssertEqual(model.tab, .today)
        XCTAssertEqual(model.projectPath, [project])
        XCTAssertEqual(model.toast?.message, "Created Garden")
    }

    func testUndoCreateLeavesDetailFirst() throws {
        let (model, env) = try makeModel()
        model.createProject(from: ProjectDraft(name: "Garden"))

        model.undo()

        XCTAssertTrue(model.projectPath.isEmpty)
        XCTAssertTrue(env.store.projects().isEmpty)
    }

    func testUndoOfALaterActionKeepsDetailOpen() throws {
        let (model, env) = try makeModel()
        model.createProject(from: ProjectDraft(name: "Garden", rows: [.step("Buy seeds")]))
        let project = try XCTUnwrap(env.store.projects().first)

        XCTAssertTrue(model.addStep("Dig beds", to: project))
        XCTAssertEqual(model.toast?.message, "Added to Garden")
        model.undo()

        XCTAssertEqual(model.projectPath, [project])
        XCTAssertEqual(project.orderedSteps.map(\.text), ["Buy seeds"])
    }

    func testAddEmptyStepDoesNothing() throws {
        let (model, env) = try makeModel()
        let project = env.addProject("Garden", steps: [("Buy seeds", "Steps")])
        XCTAssertFalse(model.addStep("   ", to: project))
        XCTAssertNil(model.toast)
    }

    func testPinnedBarShowsOnProjectDetail() throws {
        let (model, env) = try makeModel()
        let project = env.addProject("Garden", steps: [("Buy seeds", "Steps")])
        XCTAssertFalse(model.showsPinnedUpFirst)
        model.openProject(project)
        XCTAssertTrue(model.showsPinnedUpFirst)
    }
}

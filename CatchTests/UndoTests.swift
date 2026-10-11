import XCTest
@testable import Catch

@MainActor
final class UndoTests: XCTestCase {
    func testNothingToUndoAtStart() throws {
        let env = try TestEnvironment()
        XCTAssertFalse(env.store.canUndo)
        env.store.undo()
        XCTAssertFalse(env.store.canUndo)
    }

    func testUndoCapture() throws {
        let env = try TestEnvironment()
        env.add("A", to: .inbox)
        XCTAssertTrue(env.store.canUndo)

        env.store.undo()

        XCTAssertTrue(env.store.allItems().isEmpty)
        XCTAssertFalse(env.store.canUndo)
    }

    func testUndoDone() throws {
        let env = try TestEnvironment()
        let item = env.add("A", to: .now)
        env.store.setDone(item, true)
        env.store.undo()
        XCTAssertFalse(item.isDone)
    }

    func testUndoStepDone() throws {
        let env = try TestEnvironment()
        let project = env.addProject("Reno", steps: [("Measure", "Plan")])
        let step = project.orderedSteps[0]
        env.store.setDone(step, true)
        env.store.undo()
        XCTAssertFalse(step.isDone)
    }

    func testUndoMoveRestoresListReasonAndReminder() throws {
        let env = try TestEnvironment()
        let item = env.add("A", to: .later)
        let reminder = item.reminder

        env.store.move(item, to: .now)
        env.store.undo()

        XCTAssertEqual(item.list, .later)
        XCTAssertEqual(item.reminder, reminder)
        XCTAssertNil(item.reason)
    }

    func testUndoSwap() throws {
        let env = try TestEnvironment()
        let outgoing = env.add("Out", to: .now)
        let incoming = env.add("In", to: .someday)

        env.store.swap(incoming: incoming, outgoing: outgoing)
        env.store.undo()

        XCTAssertEqual(outgoing.list, .now)
        XCTAssertEqual(outgoing.reason, "You just added it to Now")
        XCTAssertEqual(incoming.list, .someday)
    }

    func testUndoDeleteBringsTheItemBack() throws {
        let env = try TestEnvironment()
        let item = env.add("Keep me", to: .later)
        item.note = "A note"
        let id = item.id
        let reminder = item.remindAt

        env.store.delete(item)
        XCTAssertTrue(env.store.allItems().isEmpty)
        env.store.undo()

        let restored = try XCTUnwrap(env.store.allItems().first)
        XCTAssertEqual(restored.id, id)
        XCTAssertEqual(restored.text, "Keep me")
        XCTAssertEqual(restored.note, "A note")
        XCTAssertEqual(restored.list, .later)
        XCTAssertEqual(restored.remindAt, reminder)
    }

    func testUndoAllToTomorrow() throws {
        let env = try TestEnvironment()
        env.add("A", to: .now)
        env.add("B", to: .now)
        env.store.moveAllToTomorrow()
        env.store.undo()
        XCTAssertEqual(env.store.openNowItems.count, 2)
    }

    func testUndoCreateProjectRestoresInboxItems() throws {
        let env = try TestEnvironment()
        let used = env.add("Renew passport", to: .inbox)
        let draft = ProjectDraft(name: "Lisbon", rows: [.step(used.text, fromInbox: used)])

        env.store.createProject(from: draft)
        env.store.undo()

        XCTAssertTrue(env.store.projects().isEmpty)
        XCTAssertEqual(env.store.items(in: .inbox).map(\.text), ["Renew passport"])
    }

    func testUndoAddStep() throws {
        let env = try TestEnvironment()
        let project = env.addProject("Reno", steps: [("Measure", "Plan"), ("Build", "Build")])

        env.store.addStep("Budget", to: project)
        env.store.undo()

        XCTAssertEqual(project.orderedSteps.map(\.text), ["Measure", "Build"])
    }

    func testOnlyTheLatestActionIsUndone() throws {
        let env = try TestEnvironment()
        let item = env.add("A", to: .now)
        env.store.setDone(item, true)
        env.store.undo()
        env.store.undo()

        XCTAssertFalse(item.isDone)
        XCTAssertEqual(env.store.allItems().count, 1, "The capture before the undone action stays")
    }

    func testRefusedMoveDoesNotReplaceUndo() throws {
        let env = try TestEnvironment()
        env.add("A", to: .now)
        env.add("B", to: .now)
        let last = env.add("C", to: .now)
        let item = env.add("D", to: .inbox)
        env.store.setDone(last, true)
        env.store.setDone(last, false)

        XCTAssertEqual(env.store.move(item, to: .now), .nowIsFull)
        env.store.undo()

        XCTAssertTrue(last.isDone, "Undo reverses the last real change, not the refused move")
    }
}

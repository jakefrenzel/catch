import XCTest
@testable import Catch

@MainActor
final class EditTests: XCTestCase {
    private func makeModel() throws -> (AppModel, TestEnvironment) {
        let env = try TestEnvironment()
        env.settingsStore.settings.haptics = false
        return (AppModel(store: env.store, settingsStore: env.settingsStore), env)
    }

    func testEditChangesTextNoteAndListTogether() throws {
        let env = try TestEnvironment()
        let item = env.add("Draft", to: .inbox)

        XCTAssertEqual(env.store.edit(item, text: " Final ", note: " Details ", list: .someday), .moved)

        XCTAssertEqual(item.text, "Final")
        XCTAssertEqual(item.note, "Details")
        XCTAssertEqual(item.list, .someday)
    }

    func testOneUndoReversesTheWholeEdit() throws {
        let env = try TestEnvironment()
        let item = env.add("Draft", to: .inbox)

        env.store.edit(item, text: "Final", note: "Details", list: .now)
        env.store.undo()

        XCTAssertEqual(item.text, "Draft")
        XCTAssertNil(item.note)
        XCTAssertEqual(item.list, .inbox)
        XCTAssertNil(item.reason)
    }

    func testEditIntoFullNowChangesNothing() throws {
        let env = try TestEnvironment()
        env.add("A", to: .now)
        env.add("B", to: .now)
        env.add("C", to: .now)
        let item = env.add("D", to: .inbox)

        XCTAssertEqual(env.store.edit(item, text: "Changed", note: nil, list: .now), .nowIsFull)

        XCTAssertEqual(item.text, "D")
        XCTAssertEqual(item.list, .inbox)
    }

    func testEditingAnItemAlreadyInFullNowIsAllowed() throws {
        let env = try TestEnvironment()
        env.add("A", to: .now)
        env.add("B", to: .now)
        let item = env.add("C", to: .now)

        XCTAssertEqual(env.store.edit(item, text: "C renamed", note: nil, list: .now), .moved)
        XCTAssertEqual(item.text, "C renamed")
    }

    func testEditToLaterGetsDefaultReminder() throws {
        let env = try TestEnvironment()
        let item = env.add("A", to: .inbox)
        env.store.edit(item, text: "A", note: nil, list: .later)
        XCTAssertEqual(item.reminder, .date(env.clock.at(day: 9, hour: 17, minute: 30)))
    }

    func testSaveEditClosesSheetAndShowsToast() throws {
        let (model, env) = try makeModel()
        let item = env.add("A", to: .inbox)
        model.openEditor(for: item)

        model.saveEdit(item, text: "B", note: "", list: .inbox)

        XCTAssertNil(model.sheet)
        XCTAssertEqual(model.toast?.message, "Saved")
        XCTAssertEqual(item.text, "B")
    }

    func testRemindMeFromEditorKeepsEditsAndOpensRemind() throws {
        let (model, env) = try makeModel()
        let item = env.add("A", to: .inbox)
        model.openEditor(for: item)

        model.saveEditAndPickTime(item, text: "A edited", note: "Note")

        XCTAssertEqual(item.text, "A edited")
        XCTAssertEqual(item.list, .later)
        guard case .remind(let target)? = model.sheet else { return XCTFail("Expected the Remind sheet") }
        XCTAssertEqual(target, item)
    }

    func testDeleteFromEditor() throws {
        let (model, env) = try makeModel()
        let item = env.add("A", to: .inbox)
        model.openEditor(for: item)

        model.deleteFromEditor(item)

        XCTAssertNil(model.sheet)
        XCTAssertEqual(model.toast?.message, "Deleted")
        XCTAssertTrue(env.store.allItems().isEmpty)
    }
}

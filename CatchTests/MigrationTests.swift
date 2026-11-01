import SwiftData
import XCTest
@testable import Catch

/// A database saved by the shipped app must still open, with nothing lost.
final class MigrationTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appending(path: "MigrationTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testStoreSavedBy1_0OpensWithTheCurrentSchema() throws {
        let url = directory.appending(path: "Catch.store")

        // As 1.0 and 1.0.1 opened it: the plain, unversioned list of models.
        try {
            let old = try ModelContainer(for: Schema(SchemaV1.models), configurations: ModelConfiguration(url: url))
            let context = ModelContext(old)
            let item = SchemaV1.Item(text: "Renew passport")
            item.note = "Photos are in the drawer"
            item.listRaw = "later"
            let place = SchemaV1.Place(name: "Home")
            item.place = place
            item.placeTriggerRaw = "arrive"
            let project = SchemaV1.Project(name: "Lisbon")
            let step = SchemaV1.Step(text: "Book flights")
            context.insert(item)
            context.insert(place)
            context.insert(project)
            context.insert(step)
            step.project = project
            try context.save()
        }()

        let container = try ModelContainer(for: CatchSchema.schema, migrationPlan: CatchMigrationPlan.self,
                                           configurations: ModelConfiguration(url: url))
        let context = ModelContext(container)

        let item = try XCTUnwrap(context.fetch(FetchDescriptor<Item>()).first)
        XCTAssertEqual(item.text, "Renew passport")
        XCTAssertEqual(item.note, "Photos are in the drawer")
        XCTAssertEqual(item.list, .later)
        XCTAssertEqual(item.place?.name, "Home")

        let step = try XCTUnwrap(context.fetch(FetchDescriptor<Step>()).first)
        XCTAssertEqual(step.text, "Book flights")
        XCTAssertEqual(step.project?.name, "Lisbon")
        XCTAssertNil(step.note)

        // And the new property saves.
        step.note = "Window seat"
        try context.save()
    }
}

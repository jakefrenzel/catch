import Foundation
import SwiftData

/// The database's shape, by version. The top-level `Item`, `Project`, `Step` and
/// `Place` are always the current version; older versions keep frozen copies of
/// their stored properties so SwiftData can recognise a store saved by an older
/// build and migrate it.
///
/// To change a stored property: add `SchemaV(n+1)` listing the top-level models,
/// copy the current models into `SchemaV(n)` as they are before the change,
/// and add a stage to `CatchMigrationPlan`.
enum CatchSchema {
    typealias Current = SchemaV2

    static let models: [any PersistentModel.Type] = Current.models
    static var schema: Schema { Schema(versionedSchema: Current.self) }
}

/// 1.0 and 1.0.1, as shipped.
enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Item.self, Project.self, Step.self, Place.self] }

    @Model
    final class Item {
        var id: UUID = UUID()
        var text: String = ""
        var note: String?
        var listRaw: String = "inbox"
        var capturedAt: Date = Date()
        var completedAt: Date?
        var remindAt: Date?
        var placeTriggerRaw: String?
        var place: Place?
        var nudge: Bool?
        var reason: String?
        var movedToTomorrow: Bool = false
        var movedToTomorrowAt: Date?

        init(text: String) { self.text = text }
    }

    @Model
    final class Project {
        var id: UUID = UUID()
        var name: String = ""
        var isExpanded: Bool = true
        var sortOrder: Int = 0
        var createdAt: Date = Date()

        @Relationship(deleteRule: .cascade, inverse: \Step.project)
        var steps: [Step]? = []

        init(name: String) { self.name = name }
    }

    @Model
    final class Step {
        var id: UUID = UUID()
        var text: String = ""
        var phase: String = "Steps"
        var sortOrder: Int = 0
        var completedAt: Date?
        var project: Project?

        init(text: String) { self.text = text }
    }

    @Model
    final class Place {
        var id: UUID = UUID()
        var name: String = ""
        var address: String = ""
        var latitude: Double = 0
        var longitude: Double = 0
        var radiusMeters: Double = 150

        @Relationship(deleteRule: .nullify, inverse: \Item.place)
        var items: [Item]? = []

        init(name: String) { self.name = name }
    }
}

/// Steps keep a note, so an Inbox item's note survives becoming a step.
enum SchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] { [Item.self, Project.self, Step.self, Place.self] }
}

enum CatchMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self] }

    static var stages: [MigrationStage] {
        // Only a new optional property: SwiftData fills it with nil.
        [.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)]
    }
}

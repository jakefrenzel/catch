import SwiftData

enum CatchSchema {
    static let models: [any PersistentModel.Type] = [Item.self, Project.self, Step.self, Place.self]
}

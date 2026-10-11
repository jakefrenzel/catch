import Foundation
import SwiftData

@Model
final class Project {
    var id: UUID = UUID()
    var name: String = ""
    var isExpanded: Bool = true
    /// Order on Today, which is also priority for Up first.
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \Step.project)
    var steps: [Step]? = []

    init(name: String, sortOrder: Int = 0, createdAt: Date = .now) {
        self.name = name
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}

@Model
final class Step {
    var id: UUID = UUID()
    var text: String = ""
    /// Phase name. Phase order is the order phases first appear in the steps.
    var phase: String = "Steps"
    var sortOrder: Int = 0
    var completedAt: Date?
    var project: Project?

    init(text: String, phase: String = Step.defaultPhase, sortOrder: Int = 0) {
        self.text = text
        self.phase = phase
        self.sortOrder = sortOrder
    }

    static let defaultPhase = "Steps"

    var isDone: Bool { completedAt != nil }
}

/// All steps with the same phase name, shown as one node on the Project Detail timeline.
struct Phase: Identifiable {
    let name: String
    let steps: [Step]

    var id: String { name }
    var isDone: Bool { steps.allSatisfy(\.isDone) }
    var doneCount: Int { steps.filter(\.isDone).count }
}

extension Project {
    var orderedSteps: [Step] {
        (steps ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    /// The first unfinished step. Shown with the "Next" chip and offered to Up first.
    var nextStep: Step? { orderedSteps.first { !$0.isDone } }

    var doneCount: Int { orderedSteps.filter(\.isDone).count }

    /// 0...1, for the progress ring.
    var progress: Double {
        let total = orderedSteps.count
        return total == 0 ? 0 : Double(doneCount) / Double(total)
    }

    var phases: [Phase] {
        let ordered = orderedSteps
        var names: [String] = []
        for step in ordered where !names.contains(step.phase) {
            names.append(step.phase)
        }
        return names.map { name in Phase(name: name, steps: ordered.filter { $0.phase == name }) }
    }

    /// Index of the first unfinished phase, or nil when everything is done.
    var currentPhaseIndex: Int? { phases.firstIndex { !$0.isDone } }
}

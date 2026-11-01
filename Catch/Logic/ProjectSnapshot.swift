import Foundation
import SwiftData

/// A step's stored values, so deleting it (or its project) can be undone.
struct StepSnapshot: Equatable {
    let id: UUID
    let text: String
    let phase: String
    let sortOrder: Int
    let completedAt: Date?
    let note: String?

    init(_ step: Step) {
        id = step.id
        text = step.text
        phase = step.phase
        sortOrder = step.sortOrder
        completedAt = step.completedAt
        note = step.note
    }

    /// A new step with the same contents and id.
    func recreate() -> Step {
        let step = Step(text: text, phase: phase, sortOrder: sortOrder, note: note)
        step.id = id
        step.completedAt = completedAt
        return step
    }
}

/// A project and its steps, so deleting it can be undone.
struct ProjectSnapshot: Equatable {
    let id: UUID
    let name: String
    let isExpanded: Bool
    let sortOrder: Int
    let createdAt: Date
    let steps: [StepSnapshot]

    init(_ project: Project) {
        id = project.id
        name = project.name
        isExpanded = project.isExpanded
        sortOrder = project.sortOrder
        createdAt = project.createdAt
        steps = project.orderedSteps.map(StepSnapshot.init)
    }

    /// Inserts a new project with the same contents and ids into `context`.
    @discardableResult
    func recreate(in context: ModelContext) -> Project {
        let project = Project(name: name, sortOrder: sortOrder, createdAt: createdAt)
        project.id = id
        project.isExpanded = isExpanded
        context.insert(project)
        let recreated = steps.map { $0.recreate() }
        for step in recreated { context.insert(step) }
        project.steps = recreated
        return project
    }
}

import Foundation

/// Something Up first can suggest: an open Now item or a project's next step.
enum UpFirstCandidate: Equatable {
    case item(Item)
    case step(Step, project: Project)

    var key: UUID {
        switch self {
        case .item(let item): return item.id
        case .step(let step, _): return step.id
        }
    }

    var title: String {
        switch self {
        case .item(let item): return item.text
        case .step(let step, _): return step.text
        }
    }

    var reason: String {
        switch self {
        case .item(let item): return item.reason ?? Reason.firstOpenInNow
        case .step(_, let project): return Reason.nextStep(in: project.name)
        }
    }
}

/// Picks the single next thing to do. Holds the transient skip list.
struct UpFirst {
    var skipped: Set<UUID> = []

    /// Open Now items in the given order, then each project's next step
    /// (in project order) when `includeSteps` is on.
    static func candidates(items: [Item], projects: [Project], includeSteps: Bool) -> [UpFirstCandidate] {
        var result = items.filter(\.isOpenInNow).map(UpFirstCandidate.item)
        if includeSteps {
            for project in projects.sorted(by: { $0.sortOrder < $1.sortOrder }) {
                if let step = project.nextStep {
                    result.append(.step(step, project: project))
                }
            }
        }
        return result
    }

    /// The first candidate that hasn't been skipped.
    func current(in candidates: [UpFirstCandidate]) -> UpFirstCandidate? {
        candidates.first { !skipped.contains($0.key) } ?? candidates.first
    }

    /// Skips the current suggestion. Once everything has been skipped, starts over.
    mutating func skip(in candidates: [UpFirstCandidate]) {
        guard let current = current(in: candidates) else { return }
        skipped.insert(current.key)
        if candidates.allSatisfy({ skipped.contains($0.key) }) {
            skipped = []
        }
    }
}

import Foundation

/// What the New Project sheet is editing before the project is created.
struct ProjectDraft {
    enum Row: Equatable {
        case phase(String)
        /// `fromInbox` is set when the step came from an Inbox chip; that item
        /// leaves the Inbox when the project is created.
        case step(String, fromInbox: Item? = nil)
    }

    struct ResolvedStep: Equatable {
        let text: String
        let phase: String
    }

    static let placeholderStep = "Decide the first step"
    static let suggestedPhaseNames = ["Plan", "Do", "Finish"]

    var name = ""
    var rows: [Row] = []

    var hasName: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var inboxItems: [Item] {
        rows.compactMap { row in
            if case .step(_, let item?) = row { return item }
            return nil
        }
    }

    /// Plan → Do → Finish, then "Phase 4", "Phase 5", …
    var nextPhaseName: String {
        let count = rows.filter { if case .phase = $0 { return true }; return false }.count
        return count < Self.suggestedPhaseNames.count ? Self.suggestedPhaseNames[count] : "Phase \(count + 1)"
    }

    mutating func addPhase() {
        rows.append(.phase(nextPhaseName))
    }

    /// Steps after a phase heading belong to it. Steps before the first heading,
    /// or in a draft with no headings, go in the default "Steps" phase.
    func resolvedSteps() -> [ResolvedStep] {
        var phase = Step.defaultPhase
        var result: [ResolvedStep] = []
        for (index, row) in rows.enumerated() {
            switch row {
            case .phase(let name):
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                phase = trimmed.isEmpty ? "Phase \(index + 1)" : trimmed
            case .step(let text, _):
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    result.append(ResolvedStep(text: trimmed, phase: phase))
                }
            }
        }
        return result
    }
}

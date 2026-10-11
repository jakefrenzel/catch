import SwiftUI

/// 6b: a project's phases as a vertical timeline. Done phases collapse, the
/// current phase shows its steps with an Add Step field, upcoming ones are dimmed.
struct ProjectDetailView: View {
    let project: Project

    @Environment(AppModel.self) private var model
    @State private var newStep = ""
    @FocusState private var isAddingStep: Bool

    var body: some View {
        let phases = project.phases
        let current = project.currentPhaseIndex

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header(phases: phases, current: current)

                ForEach(Array(phases.enumerated()), id: \.element.id) { index, phase in
                    PhaseNode(phase: phase,
                              state: state(of: index, current: current, isDone: phase.isDone),
                              previousName: index > 0 ? phases[index - 1].name : nil,
                              isLast: index == phases.count - 1,
                              nextStepID: project.nextStep?.id,
                              newStep: $newStep,
                              isAddingStep: $isAddingStep,
                              onToggle: { model.toggleDone($0) },
                              onAddStep: addStep)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 180)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Theme.bg)
        .toolbar(.visible, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func header(phases: [Phase], current: Int?) -> some View {
        let steps = project.orderedSteps
        let subtitle: String
        if let current {
            subtitle = "\(project.doneCount) of \(steps.count) steps · Phase \(current + 1) of \(phases.count)"
        } else {
            subtitle = "All \(steps.count) steps done"
        }
        return HStack(spacing: 14) {
            ProgressRing(progress: project.progress, size: 44, lineWidth: 6)
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.title.bold())
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink2)
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 22)
        .accessibilityElement(children: .combine)
    }

    /// A phase finished ahead of the current one shows as done too.
    private func state(of index: Int, current: Int?, isDone: Bool) -> PhaseNode.State {
        guard let current else { return .done }
        if index == current { return .current }
        return index < current || isDone ? .done : .upcoming
    }

    private func addStep() {
        if model.addStep(newStep, to: project) {
            newStep = ""
            isAddingStep = true
        }
    }
}

private struct PhaseNode: View {
    enum State { case done, current, upcoming }

    let phase: Phase
    let state: State
    let previousName: String?
    let isLast: Bool
    let nextStepID: UUID?
    @Binding var newStep: String
    var isAddingStep: FocusState<Bool>.Binding
    let onToggle: (Step) -> Void
    let onAddStep: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                marker
                Rectangle()
                    .fill(isLast ? Color.clear : (state == .done ? Theme.blue : Theme.sep))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 24)

            VStack(alignment: .leading, spacing: state == .current ? 10 : 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(phase.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(titleColor)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Text(stat)
                        .font(.footnote)
                        .foregroundStyle(Theme.ink2)
                }
                .padding(.top, 1)

                if state == .current {
                    stepsCard
                } else {
                    Text(phase.steps.map(\.text).joined(separator: " · "))
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink2)
                        .lineSpacing(2)
                }
            }
            .padding(.bottom, 18)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var marker: some View {
        switch state {
        case .done:
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Theme.blue, in: Circle())
        case .current:
            Circle()
                .strokeBorder(Theme.blue, lineWidth: 2)
                .overlay(Circle().fill(Theme.blue).frame(width: 10, height: 10))
                .frame(width: 24, height: 24)
        case .upcoming:
            Circle()
                .strokeBorder(Theme.ink4, lineWidth: 1.5)
                .frame(width: 24, height: 24)
        }
    }

    private var titleColor: Color {
        switch state {
        case .done: return Color.primary
        case .current: return Theme.blue
        case .upcoming: return Theme.ink2
        }
    }

    private var stat: String {
        switch state {
        case .done: return "Done"
        case .current: return "\(phase.doneCount) of \(phase.steps.count)"
        case .upcoming: return previousName.map { "After \($0)" } ?? ""
        }
    }

    private var stepsCard: some View {
        VStack(spacing: 0) {
            ForEach(phase.steps) { step in
                let isNext = step.id == nextStepID
                HStack(spacing: 10) {
                    CheckCircle(isDone: step.isDone, color: Theme.blue, size: 22) { onToggle(step) }
                        .accessibilityLabel(step.isDone ? "Mark not done: \(step.text)" : "Mark done: \(step.text)")
                    Text(step.text)
                        .font(.callout.weight(isNext ? .semibold : .regular))
                        .lineLimit(3)
                        .foregroundStyle(step.isDone ? Theme.ink3 : Color.primary)
                        .strikethrough(step.isDone, color: Theme.ink3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if isNext {
                        NextChip()
                    }
                }
                .padding(.vertical, 11)
                .padding(.trailing, 12)
                .overlay(alignment: .bottom) { Theme.sep.frame(height: 1) }
            }

            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.blue)
                    .frame(width: 22)
                    .accessibilityHidden(true)
                TextField("Add Step", text: $newStep)
                    .font(.callout)
                    .submitLabel(.done)
                    .focused(isAddingStep)
                    .onSubmit(onAddStep)
            }
            .padding(.vertical, 12)
            .padding(.trailing, 12)
        }
        .padding(.leading, 14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// The small blue "Next" chip on a project's next step.
struct NextChip: View {
    var body: some View {
        Text("Next")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.blue)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Theme.blueTint, in: RoundedRectangle(cornerRadius: 8))
    }
}

import SwiftUI

/// Project on Today: progress ring, name and "2 of 5". The chevron shows the steps inline.
struct ProjectRow: View {
    let project: Project
    let onOpen: () -> Void
    let onToggleExpanded: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let steps = project.orderedSteps
        HStack(spacing: 0) {
            Button(action: onOpen) {
                HStack(spacing: 12) {
                    ProgressRing(progress: project.progress)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(project.name)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("\(project.doneCount) of \(steps.count)")
                            .font(.footnote)
                            .foregroundStyle(Theme.ink2)
                    }
                    .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("\(project.name), \(project.doneCount) of \(steps.count) steps done")
            .accessibilityHint("Opens the project.")

            Button {
                withAnimation(reduceMotion ? nil : .catchEaseOut(0.3)) { onToggleExpanded() }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink4)
                    .rotationEffect(.degrees(project.isExpanded ? 180 : 0))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(project.isExpanded ? "Hide steps" : "Show steps")
        }
        .padding(.vertical, -4)
    }
}

/// An inline step under an expanded project, indented to line up with the project name.
struct StepRow: View {
    let step: Step
    let isNext: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            CheckCircle(isDone: step.isDone, color: Theme.blue, size: 20, action: onToggle)
                .accessibilityLabel(step.isDone ? "Mark not done: \(step.text)" : "Mark done: \(step.text)")
            Text(step.text)
                .font(.subheadline.weight(isNext ? .semibold : .regular))
                .foregroundStyle(step.isDone ? Theme.ink3 : .primary)
                .strikethrough(step.isDone, color: Theme.ink3)
                .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
            if isNext {
                Text("Next")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.blue)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Theme.blueTint, in: RoundedRectangle(cornerRadius: 8))
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 38)
        .padding(.vertical, -4)
    }
}

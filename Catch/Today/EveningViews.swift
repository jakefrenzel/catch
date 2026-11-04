import SwiftUI

/// Replaces Up first from the wrap-up time: what's left and a Finish button.
struct EveningCard: View {
    let card: WrapUp.Card
    let onFinish: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "moon.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.orangeText)
                .frame(width: 36, height: 36)
                .background(Theme.orangeTint, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(card.title)
                    .font(.headline)
                Text(card.subtitle)
                    .font(.footnote)
                    .foregroundStyle(Theme.ink2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            if card.canFinish {
                Button(action: onFinish) {
                    Text("Finish")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.orangeText)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 36)
                        .background(Theme.orange.opacity(0.16), in: Capsule())
                }
                .buttonStyle(.borderless)
                .accessibilityHint("Moves what's left to tomorrow.")
            }
        }
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 14))
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .cardShadow()
    }
}

/// The Tomorrow | Someday control on each open Now row in the evening.
struct EveningRowActions: View {
    let onTomorrow: () -> Void
    let onSomeday: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            button("Tomorrow", action: onTomorrow)
            button("Someday", action: onSomeday)
        }
        .padding(2)
        .background(Theme.fill, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        // Keep both words whole; the item title wraps instead.
        .fixedSize()
    }

    private func button(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .contentShape(Rectangle().inset(by: -8))
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Move to \(title)")
    }
}

/// The top of the evening wrap-up: what got done today, then the project it moved closest to done.
/// Shown only when something was done; a day with nothing done says nothing about it.
struct DoneTodayCard: View {
    let summary: WrapUp.Summary
    /// After Finish it says the day is over, and Finish's own card steps aside.
    let isFinished: Bool
    let movedToTomorrow: Int
    let onNotDone: (WrapUp.Done) -> Void
    let onOpenProject: (UUID) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsAll = false
    /// A long day folds after this many.
    private let foldAfter = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 8)

            let shown = showsAll ? summary.done : Array(summary.done.prefix(foldAfter))
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(shown.enumerated()), id: \.element.id) { index, entry in
                    DoneEntryRow(entry: entry)
                        .contextMenu {
                            Button { onNotDone(entry) } label: {
                                Label("Not Done", systemImage: "arrow.uturn.backward")
                            }
                        }
                        .overlay(alignment: .bottom) {
                            if index < shown.count - 1 || summary.count > foldAfter {
                                Theme.sep.frame(height: 1)
                            }
                        }
                }
                if summary.count > foldAfter {
                    Button {
                        withAnimation(reduceMotion ? nil : .catchEaseOut(0.3)) { showsAll.toggle() }
                    } label: {
                        Text(showsAll ? "Show Less" : "\(summary.count - foldAfter) More")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.blue)
                            .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.leading, 48)

            if let closer = summary.closer {
                Button { onOpenProject(closer.projectID) } label: {
                    HStack(spacing: 12) {
                        ProgressRing(progress: closer.progress)
                            .frame(width: 36)
                        Text(closer.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.primary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(closer.label)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(closer.left == 0 ? Theme.green : Theme.blue)
                            .lineLimit(1)
                    }
                    .padding(.vertical, 11)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(closer.name), \(closer.label)")
                .accessibilityHint("Opens the project.")
                .overlay(alignment: .top) { Theme.sep.frame(height: 1).padding(.horizontal, -16) }
                .padding(.top, 6)
            }
        }
        .padding(EdgeInsets(top: 14, leading: 16, bottom: summary.closer == nil ? 8 : 0, trailing: 16))
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .cardShadow()
    }

    private var header: some View {
        HStack(spacing: 12) {
            Group {
                if isFinished {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.orangeText)
                        .background(Circle().fill(Theme.orangeTint).frame(width: 36, height: 36))
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.green)
                        .background(Circle().fill(Theme.greenTint).frame(width: 36, height: 36))
                }
            }
            .frame(width: 36, height: 36)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(isFinished ? "Day finished" : summary.title)
                    .font(.headline)
                if let line = isFinished ? summary.finishedLine(movedToTomorrow: movedToTomorrow) : summary.stepsLine {
                    Text(line)
                        .font(.footnote)
                        .foregroundStyle(Theme.ink2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
        }
    }
}

/// One thing done today: a small filled check in its list's color, the title, and its time or project.
private struct DoneEntryRow: View {
    let entry: WrapUp.Done

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(color, in: Circle())
                .accessibilityHidden(true)
            Text(entry.title)
                .font(.subheadline)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            detail
        }
        .padding(.vertical, 7)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var color: Color {
        if case .later = entry.kind { return Theme.orange }
        return Theme.blue
    }

    @ViewBuilder
    private var detail: some View {
        switch entry.kind {
        case .now:
            EmptyView()
        case .later:
            if let reminder = entry.item?.reminder {
                Text(ReminderFormatter().label(for: reminder, now: entry.completedAt))
                    .font(.footnote)
                    .foregroundStyle(Theme.ink2)
                    .lineLimit(1)
            }
        case .step(let project):
            Text(project)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.blue)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Theme.blueTint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var accessibilityText: String {
        switch entry.kind {
        case .now, .later: return "\(entry.title), done"
        case .step(let project): return "\(entry.title), step in \(project), done"
        }
    }
}

/// "4 new ideas · Can wait until tomorrow", under Now in the evening.
struct EveningInboxRow: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "tray.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Theme.red, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(count) new idea\(count == 1 ? "" : "s")")
                        .foregroundStyle(Color.primary)
                    Text("Can wait until tomorrow")
                        .font(.footnote)
                        .foregroundStyle(Theme.ink2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.ink4)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

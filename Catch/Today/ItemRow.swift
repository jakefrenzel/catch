import SwiftUI

/// A Now or Later row: check circle, title, optional note, and (for Later) the reminder time.
struct ItemRow: View {
    let item: Item
    let accent: Color
    var showsTime = false
    var notificationsOn = true
    let onToggle: () -> Void
    let onEdit: () -> Void
    var onTime: () -> Void = {}
    /// Set in the evening to show the Tomorrow | Someday control.
    var onTomorrow: (() -> Void)?
    var onSomeday: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            CheckCircle(isDone: item.isDone, color: accent, action: onToggle)
                .accessibilityLabel(item.isDone ? "Mark not done: \(item.text)" : "Mark done: \(item.text)")

            VStack(alignment: .leading, spacing: 2) {
                Text(item.text)
                    .foregroundStyle(item.isDone ? Theme.ink3 : .primary)
                    .strikethrough(item.isDone, color: Theme.ink3)
                if let note = item.note {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(Theme.ink2)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
            .contentShape(Rectangle())
            .onTapGesture(perform: onEdit)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityText)
            .accessibilityHint("Double-tap to edit.")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default, onEdit)

            if let onTomorrow, let onSomeday {
                EveningRowActions(onTomorrow: onTomorrow, onSomeday: onSomeday)
                    .padding(.trailing, -6)
            }

            if showsTime, let reminder = item.reminder {
                Button(action: onTime) {
                    HStack(spacing: 4) {
                        if !notificationsOn {
                            Image(systemName: "bell.slash")
                                .font(.footnote)
                        }
                        Text(ReminderFormatter().label(for: reminder, now: .now))
                            .lineLimit(1)
                    }
                    .font(.subheadline)
                    .foregroundStyle(notificationsOn ? Theme.orangeText : Theme.ink2)
                    .contentShape(Rectangle().inset(by: -12))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Reminder time")
                .accessibilityValue(ReminderFormatter().label(for: reminder, now: .now))
            }
        }
        .padding(.vertical, -2)
    }

    private var accessibilityText: String {
        var parts = [item.text]
        if showsTime, let reminder = item.reminder {
            parts.append(ReminderFormatter().label(for: reminder, now: .now))
        }
        if item.isDone { parts.append("done") }
        return parts.joined(separator: ", ")
    }
}

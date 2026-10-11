import SwiftData
import SwiftUI

/// Sort captures one at a time: the oldest is on the card, the next few queue below.
struct InboxView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(filter: #Predicate<Item> { $0.listRaw == "inbox" }, sort: \Item.capturedAt)
    private var inbox: [Item]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeader(title: "Inbox", subtitle: inbox.isEmpty ? "All sorted" : "\(inbox.count) to sort")

                if let current = inbox.first {
                    CurrentItemCard(item: current,
                                    onEdit: { model.openEditor(for: current) },
                                    onDelete: { model.delete(current) })
                        .id(current.id)
                        .transition(reduceMotion
                                    ? .opacity
                                    : .asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.96)),
                                                  removal: .opacity.combined(with: .move(edge: .leading))))
                        .padding(.horizontal, 16)

                    sortButtons(for: current)
                        .padding(.top, 26)
                        .padding(.horizontal, 16)

                    let queue = Array(inbox.dropFirst().prefix(4))
                    if !queue.isEmpty {
                        upNext(queue)
                    }
                } else {
                    EmptyInboxCard { model.tab = .today }
                        .padding(.horizontal, 16)
                }
            }
            .animation(reduceMotion ? nil : .catchEaseOut(0.3), value: inbox.first?.id)
            .padding(.bottom, 180)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func sortButtons(for item: Item) -> some View {
        HStack(spacing: 0) {
            SortButton(title: "Someday", icon: "archivebox", iconColor: Theme.ink2, fill: Theme.card) {
                model.move(item, to: .someday)
            }
            SortButton(title: "Later", icon: "clock", iconColor: Theme.orange, fill: Theme.card) {
                model.move(item, to: .later)
            }
            SortButton(title: "Now", icon: "sun.max.fill", iconColor: .white, fill: Theme.blue,
                       shadow: Theme.blue.opacity(0.35)) {
                model.move(item, to: .now)
            }
        }
    }

    private func upNext(_ queue: [Item]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Up next")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.ink2)
                .padding(.horizontal, 20)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                ForEach(Array(queue.enumerated()), id: \.element.id) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(item.text)
                            .font(.callout)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(ReminderFormatter().caughtLabel(for: item.capturedAt, now: .now))
                            .font(.subheadline)
                            .foregroundStyle(Theme.ink2)
                            .fixedSize()
                    }
                    .padding(.vertical, 12)
                    .padding(.trailing, 16)
                    .overlay(alignment: .bottom) {
                        if index < queue.count - 1 {
                            Theme.sep.frame(height: 1)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.leading, 16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .padding(.top, 26)
        .padding(.horizontal, 16)
    }
}

/// The oldest Inbox item, big, with when it was caught and a Delete button.
private struct CurrentItemCard: View {
    let item: Item
    let onEdit: () -> Void
    let onDelete: () -> Void

    @ScaledMetric(relativeTo: .title) private var textSize: CGFloat = 26

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Caught \(ReminderFormatter().caughtLabel(for: item.capturedAt, now: .now))")
                .font(.footnote)
                .foregroundStyle(Theme.ink2)

            Spacer(minLength: 0)

            Text(item.text)
                .font(.system(size: textSize, weight: .semibold))
                .lineSpacing(2)
                .lineLimit(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(perform: onEdit)
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Double-tap to edit.")
                .accessibilityAction(.default, onEdit)

            Spacer(minLength: 0)

            Button("Delete", role: .destructive, action: onDelete)
                .font(.subheadline)
                .foregroundStyle(Theme.red)
                .frame(minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
                .buttonStyle(.plain)
        }
        .padding(EdgeInsets(top: 22, leading: 22, bottom: 10, trailing: 22))
        .frame(maxWidth: .infinity, minHeight: 230, alignment: .topLeading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 15, x: 0, y: 10)
    }
}

/// One of the three round sort buttons under the card.
private struct SortButton: View {
    let title: String
    let icon: String
    let iconColor: Color
    let fill: Color
    var shadow: Color = .black.opacity(0.08)
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(iconColor)
                    .frame(width: 64, height: 64)
                    .background(fill, in: Circle())
                    .shadow(color: shadow, radius: 5, x: 0, y: 3)
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.primary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Move to \(title)")
    }
}

private struct EmptyInboxCard: View {
    let onBackToToday: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Inbox is empty")
                .font(.title3.bold())
            Text("Everything you caught has a place. Hold + to talk, or tap it to type.")
                .font(.subheadline)
                .foregroundStyle(Theme.ink2)
            Button(action: onBackToToday) {
                Text("Back to Today")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 36)
                    .background(Theme.blue, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .cardShadow()
    }
}

/// Large title with a subtitle, as on Inbox and Someday.
struct ScreenHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Theme.ink2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EdgeInsets(top: 8, leading: 20, bottom: 16, trailing: 20))
    }
}

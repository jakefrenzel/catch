import SwiftData
import SwiftUI

/// No dates, no rush. Each row can be pulled into Now.
struct SomedayView: View {
    @Environment(AppModel.self) private var model
    @Query(filter: #Predicate<Item> { $0.listRaw == "someday" }, sort: \Item.capturedAt)
    private var someday: [Item]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeader(title: "Someday", subtitle: "No dates. Look through it once a month.")

                if someday.isEmpty {
                    EmptySomedayCard()
                        .padding(.horizontal, 16)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(someday.enumerated()), id: \.element.id) { index, item in
                            SomedayRow(item: item,
                                       onEdit: { model.openEditor(for: item) },
                                       onMoveToNow: { model.move(item, to: .now) })
                                .focusMenu { model.startChosenFocus(.item(item)) }
                                .overlay(alignment: .bottom) {
                                    if index < someday.count - 1 {
                                        Theme.sep.frame(height: 1)
                                    }
                                }
                        }
                    }
                    .padding(.leading, 16)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 180)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

private struct SomedayRow: View {
    let item: Item
    let onEdit: () -> Void
    let onMoveToNow: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(item.text)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(perform: onEdit)
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Double-tap to edit.")
                .accessibilityAction(.default, onEdit)

            Button(action: onMoveToNow) {
                Text("Move to Now")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.blue)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 30)
                    .background(Theme.blueTint, in: Capsule())
                    .contentShape(Rectangle().inset(by: -7))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Move \(item.text) to Now")
        }
        .padding(.vertical, 11)
        .padding(.trailing, 16)
    }
}

/// 10e: nothing in Someday yet.
private struct EmptySomedayCard: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "archivebox")
                .font(.system(size: 24))
                .foregroundStyle(Theme.ink2)
                .frame(width: 60, height: 60)
                .background(Theme.fill, in: Circle())
                .accessibilityHidden(true)
            Text("Nothing here yet")
                .font(.title3.bold())
            Text("Ideas with no date and no rush end up here, like “learn to make fresh pasta”. Sort one here from Inbox, or say “someday” when you talk.")
                .font(.subheadline)
                .foregroundStyle(Theme.ink2)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 26)
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .cardShadow()
    }
}

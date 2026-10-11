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
    }

    private func button(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.primary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .contentShape(Rectangle().inset(by: -8))
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Move to \(title)")
    }
}

/// "3 done today", under Now in the evening.
struct DoneTodayRow: View {
    let count: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Theme.blue, in: Circle())
                .accessibilityHidden(true)
            Text("\(count) done today")
                .foregroundStyle(Theme.ink2)
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

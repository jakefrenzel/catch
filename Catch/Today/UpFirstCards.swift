import SwiftUI

/// The suggestion at the top of Today: what to do next, why, and a Start button.
struct UpFirstCard: View {
    let candidate: UpFirstCandidate
    let onStart: () -> Void
    let onSkip: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.blue)
                .frame(width: 36, height: 36)
                .background(Theme.blueTint, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 10) {
                    Text("Up first")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.blue)
                        .fixedSize()
                    Button("Skip", action: onSkip)
                        .font(.footnote)
                        .foregroundStyle(Theme.ink2)
                        .buttonStyle(.borderless)
                        .contentShape(Rectangle().inset(by: -12))
                        .accessibilityLabel("Skip this suggestion")
                }
                Text(candidate.title)
                    .font(.headline)
                    .lineLimit(3)
                Text(candidate.reason)
                    .font(.caption)
                    .foregroundStyle(Theme.ink2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onStart) {
                Text("Start")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 36)
                    .background(Theme.blue, in: Capsule())
            }
            .buttonStyle(.borderless)
            .accessibilityHint("Opens Focus.")
        }
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 14))
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .cardShadow()
    }
}

/// Shown instead of Up first when there's nothing to suggest.
struct AllClearCard: View {
    let doneToday: Int
    let inboxCount: Int
    let hasSomeday: Bool

    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Theme.green)
                .frame(width: 60, height: 60)
                .background(Theme.greenTint, in: Circle())
                .accessibilityHidden(true)
            Text("Today is clear")
                .font(.title2.bold())
            Text(doneToday > 0
                 ? "\(doneToday) done. Nothing left in Now and no project steps waiting."
                 : "Nothing in Now and no project steps waiting.")
                .font(.subheadline)
                .foregroundStyle(Theme.ink2)
                .multilineTextAlignment(.center)

            if inboxCount > 0 || hasSomeday {
                HStack(spacing: 8) {
                    if inboxCount > 0 {
                        pill("Sort Inbox (\(inboxCount))") { model.tab = .inbox }
                    }
                    if hasSomeday {
                        pill("Pull from Someday") { model.tab = .someday }
                    }
                }
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .padding(.horizontal, 16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .cardShadow()
    }

    private func pill(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.blue)
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
                .background(Theme.blueTint, in: Capsule())
        }
        .buttonStyle(.borderless)
    }
}

/// The compact Up first bar that floats above the tab bar when the card is off screen.
/// Swipe it down to hide it.
struct PinnedUpFirstBar: View {
    let candidate: UpFirstCandidate
    let onDone: () -> Void
    let onSkip: () -> Void
    let onHide: () -> Void
    @State private var drag: CGFloat = 0

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 10) {
                    Text("Up first")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.blue)
                    Button("Skip", action: onSkip)
                        .font(.caption)
                        .foregroundStyle(Theme.ink2)
                        .buttonStyle(.borderless)
                        .contentShape(Rectangle().inset(by: -12))
                        .accessibilityLabel("Skip this suggestion")
                }
                Text(candidate.title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onDone) {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Theme.blue, in: Circle())
                    .contentShape(Rectangle().inset(by: -2))
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Mark done: \(candidate.title)")
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .floatingShadow()
        .offset(y: drag)
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { drag = max(0, $0.translation.height) }
                .onEnded { value in
                    if value.translation.height > 40 || value.predictedEndTranslation.height > 90 {
                        onHide()
                    }
                    withAnimation(.catchEaseOut(0.25)) { drag = 0 }
                }
        )
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Hide until you reopen Catch", onHide)
    }
}

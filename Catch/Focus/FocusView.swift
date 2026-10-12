import SwiftUI

/// Full-screen focus on one thing, with an elapsed timer: the Up first
/// suggestion, or anything started from a row's menu or the edit sheet.
struct FocusView: View {
    let candidate: UpFirstCandidate
    let reason: String
    let onDone: () -> Void
    let onNotNow: () -> Void
    let onClose: () -> Void

    @State private var startedAt = Date.now
    @State private var showsWholeTitle = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var timerSize: CGFloat = 64

    var body: some View {
        // Fills the screen, and scrolls once large text makes it taller.
        GeometryReader { proxy in
            ScrollView {
                content
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 14)
                    .frame(minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Theme.card.ignoresSafeArea())
    }

    private var content: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Focus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.blue)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.primary)
                        .frame(width: 44, height: 44)
                        .background(Theme.fill, in: Circle())
                }
                .accessibilityLabel("Close")
            }

            Spacer()

            VStack(alignment: .leading, spacing: 14) {
                Text(reason)
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink2)
                // A long item shows 3 lines and "…" until tapped, so the timer stays in view.
                Text(candidate.title)
                    .font(.largeTitle.bold())
                    .lineLimit(showsWholeTitle ? nil : 3)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(reduceMotion ? nil : .catchEaseOut(0.25)) { showsWholeTitle.toggle() }
                    }
                TimelineView(.periodic(from: startedAt, by: 1)) { context in
                    Text(elapsed(until: context.date))
                        .font(.system(size: timerSize, weight: .light).monospacedDigit())
                        .foregroundStyle(Theme.blue)
                        .padding(.top, 18)
                        .accessibilityLabel("Elapsed time")
                        .accessibilityValue(elapsed(until: context.date))
                }
            }

            Spacer()

            VStack(spacing: 10) {
                Button(action: onDone) {
                    Text("Mark Done")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(Theme.blue, in: Capsule())
                }
                Button(action: onNotNow) {
                    Text("Not Now")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.blue)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(Theme.fill, in: Capsule())
                }
            }
        }
    }

    private func elapsed(until date: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(startedAt)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

extension View {
    /// Long-press menu with Start Focus; none when `action` is nil (done items).
    @ViewBuilder
    func focusMenu(_ action: (() -> Void)?) -> some View {
        if let action {
            contextMenu {
                Button(action: action) {
                    Label("Start Focus", systemImage: "timer")
                }
            }
        } else {
            self
        }
    }
}

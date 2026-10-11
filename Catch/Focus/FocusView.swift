import SwiftUI

/// Full-screen focus on the Up first suggestion, with an elapsed timer.
struct FocusView: View {
    let candidate: UpFirstCandidate
    let onDone: () -> Void
    let onNotNow: () -> Void
    let onClose: () -> Void

    @State private var startedAt = Date.now
    @ScaledMetric(relativeTo: .largeTitle) private var timerSize: CGFloat = 64

    var body: some View {
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
                Text(candidate.reason)
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink2)
                Text(candidate.title)
                    .font(.largeTitle.bold())
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
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 14)
        .background(Theme.card.ignoresSafeArea())
    }

    private func elapsed(until date: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(startedAt)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

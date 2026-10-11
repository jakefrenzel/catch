import SwiftUI

/// The round check button on rows. Fills with `color` and springs a check mark in when done.
struct CheckCircle: View {
    let isDone: Bool
    let color: Color
    var size: CGFloat = 24
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .strokeBorder(isDone ? color : Theme.ink4, lineWidth: 1.5)
                Circle()
                    .fill(isDone ? color : .clear)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: isDone)
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundStyle(.white)
                    .scaleEffect(isDone ? 1 : 0.4)
                    .opacity(isDone ? 1 : 0)
                    .animation(reduceMotion ? nil : .timingCurve(0.3, 1.7, 0.5, 1, duration: 0.3), value: isDone)
            }
            .frame(width: size, height: size)
            // Grow the hit area to 44 pt without moving the circle.
            .contentShape(Rectangle().inset(by: -(44 - size) / 2))
        }
        .buttonStyle(.borderless)
    }
}

/// The 26 pt project progress ring; blue, turning green at 100%.
struct ProgressRing: View {
    let progress: Double
    var size: CGFloat = 26
    var lineWidth: CGFloat = 4

    var body: some View {
        ZStack {
            Circle().stroke(Theme.fill, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(progress, 1)))
                .stroke(progress >= 1 ? Theme.green : Theme.blue,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

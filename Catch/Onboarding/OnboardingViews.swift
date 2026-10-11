import SwiftUI

/// 8a step 0: the welcome screen on first launch.
struct WelcomeView: View {
    let onStart: () -> Void
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 40

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 18) {
                // The app icon is light grey like the background, so the edge and shadow set it apart.
                Image("AppIconImage")
                    .resizable()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.sep, lineWidth: 1))
                    .floatingShadow()
                    .accessibilityHidden(true)
                Text("Catch")
                    .font(.system(size: titleSize, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                Text("Say or type whatever's on your mind. Catch sorts it into Now, Later or Someday and tells you what to do next.")
                    .font(.body)
                    .foregroundStyle(Theme.ink2)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 36)
            Spacer()
            VStack(spacing: 12) {
                Button(action: onStart) {
                    Text("Try It")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Theme.blue, in: Capsule())
                }
                .buttonStyle(.plain)
                Text("Takes about a minute. No account needed.")
                    .font(.footnote)
                    .foregroundStyle(Theme.ink2)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.card.ignoresSafeArea())
    }
}

/// The dark coach bubble used in steps 1 and 2.
struct CoachBubble: View {
    let title: String
    let detail: String
    /// Steps 1: a tail pointing down at +.
    var pointsDown = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.body.weight(.semibold))
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(alignment: .bottomTrailing) {
            if pointsDown {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255))
                    .frame(width: 16, height: 16)
                    .rotationEffect(.degrees(45))
                    .offset(x: -30, y: 7)
            }
        }
        .background(Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 10)
        .accessibilityElement(children: .combine)
    }
}

/// "1 of 3" and friends, on the dimmed screen.
struct StepPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.white.opacity(0.2), in: Capsule())
    }
}

/// Step 1, shown above the tab bar while the rest of the screen is dimmed.
struct OnboardingHoldPrompt: View {
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                StepPill(text: "1 of 3")
                Spacer()
                Button("Skip", action: onSkip)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(minHeight: 44)
                    .buttonStyle(.plain)
            }
            CoachBubble(title: "Hold + and say something you need to do",
                        detail: "Try “Remind me to call Dana tomorrow at 10 about the lease”",
                        pointsDown: true)
        }
    }
}

/// Step 3: ask before iOS asks.
struct OnboardingPermissionSheet: View {
    let reminderDate: Date
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 12) {
            Text("3 of 3")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.ink2)
            Image(systemName: "bell.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Theme.orangeText)
                .frame(width: 60, height: 60)
                .background(Theme.orangeTint, in: Circle())
                .accessibilityHidden(true)
            Text("Remind you \(Self.label(for: reminderDate, formatter: ReminderFormatter()))?")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("Catch only sends reminders you set and one wrap-up in the evening. iOS will ask you next.")
                .font(.subheadline)
                .foregroundStyle(Theme.ink2)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            VStack(spacing: 10) {
                Button {
                    Task { await model.finishOnboarding(allowReminders: true) }
                } label: {
                    Text("Turn On Reminders")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Theme.blue, in: Capsule())
                }
                Button {
                    Task { await model.finishOnboarding(allowReminders: false) }
                } label: {
                    Text("Not Now")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.blue)
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding(EdgeInsets(top: 28, leading: 24, bottom: 16, trailing: 24))
        .fittedSheet(showsHandle: false, background: Theme.card)
        .interactiveDismissDisabled()
    }

    /// "Saturday at 10 AM", "tomorrow at 9:30 AM", "today at 5:30 PM".
    static func label(for date: Date, now: Date = .now, formatter: ReminderFormatter) -> String {
        let calendar = formatter.calendar
        let time = formatter.timeLabel(date)
        if calendar.isDate(date, inSameDayAs: now) { return "today at \(time)" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) {
            return "tomorrow at \(time)"
        }
        var weekday = Date.FormatStyle.dateTime.weekday(.wide)
        weekday.calendar = calendar
        weekday.timeZone = calendar.timeZone
        weekday.locale = formatter.locale
        return "\(date.formatted(weekday)) at \(time)"
    }
}

/// Step 2, above the voice sheet: explains the orange highlight once a time is heard.
struct OnboardingTalkCoach: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let heardTime = model.parseVoice(model.voice.transcript).chunks.first { $0.kind == .time }?.text
        VStack(alignment: .leading, spacing: 10) {
            StepPill(text: "2 of 3")
            CoachBubble(title: heardTime == nil ? "Keep holding and talk" : "Orange means a time",
                        detail: heardTime.map { "Catch heard “\($0)” and will remind you then. Let go to save." }
                            ?? "Catch listens for times, like “tomorrow at 10”.")
        }
        .allowsHitTesting(false)
    }
}

import SwiftUI
import UIKit

/// Reads the mic levels in its own body, so ten-plus level updates a second
/// redraw only the bars, not the sheet (which re-parses the transcript).
private struct LiveWaveform: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Waveform(levels: model.voice.levels)
    }
}

/// 6j: the sheet that rises while + is held. It never takes touches (the finger
/// is still on +), except under VoiceOver, which gets a Save button instead.
struct VoiceSheet: View {
    let startedAt: Date

    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @ScaledMetric(relativeTo: .title) private var transcriptSize: CGFloat = 28

    var body: some View {
        let parse = model.parseVoice(model.voice.transcript)

        VStack(alignment: .leading, spacing: 18) {
            HStack {
                HStack(spacing: 8) {
                    Circle().fill(Theme.red).frame(width: 8, height: 8)
                    Text("Listening")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.red)
                Spacer()
                TimelineView(.periodic(from: startedAt, by: 1)) { context in
                    let seconds = max(0, Int(context.date.timeIntervalSince(startedAt)))
                    Text(String(format: "%d:%02d", seconds / 60, seconds % 60))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Theme.ink2)
                }
            }

            transcript(parse)
                .font(.system(size: transcriptSize, weight: .semibold))
                .lineSpacing(6)
                .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
                .accessibilityLabel(model.voice.transcript.isEmpty ? "Listening" : model.voice.transcript)

            WillSaveCard(parse: parse)

            // Room above the waveform, but don't grow past the 460 pt design height.
            Spacer(minLength: 12)
                .frame(maxHeight: 60)

            LiveWaveform()
                .frame(height: 44)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)

            if voiceOver || model.isTapToTalk {
                HStack(spacing: 10) {
                    Button {
                        Task { await model.stopListening(save: false) }
                    } label: {
                        Text("Cancel")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.blue)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(Theme.blueTint, in: Capsule())
                    }
                    Button {
                        Task { await model.stopListening(save: true) }
                    } label: {
                        Text("Save")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(Theme.blue, in: Capsule())
                    }
                }
            } else {
                Text("Let go to save")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink2)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(EdgeInsets(top: 24, leading: 24, bottom: 120, trailing: 24))
        .frame(maxWidth: .infinity, minHeight: 460, alignment: .top)
        .background(Theme.card,
                    in: UnevenRoundedRectangle(topLeadingRadius: 38, topTrailingRadius: 38, style: .continuous))
    }

    /// Filler fades, times go orange, projects go purple.
    private func transcript(_ parse: VoiceParse) -> Text {
        guard !parse.chunks.isEmpty else {
            return Text("…").foregroundStyle(Theme.ink4)
        }
        var result = AttributedString()
        for (index, chunk) in parse.chunks.enumerated() {
            if index > 0 { result += AttributedString(" ") }
            var part = AttributedString(chunk.text)
            switch chunk.kind {
            case .normal:
                part.foregroundColor = Color.primary
            case .filler:
                part.foregroundColor = Theme.ink4
            case .time:
                part = Self.padded(chunk.text)
                part.foregroundColor = Theme.orangeText
                part.backgroundColor = Theme.orange.opacity(0.18)
            case .project:
                part = Self.padded(chunk.text)
                part.foregroundColor = Theme.purple
                part.backgroundColor = Theme.purple.opacity(0.12)
            }
            result += part
        }
        return Text(result)
    }

    /// Thin spaces inside a highlight stand in for the handoff's 0 4px padding.
    private static func padded(_ text: String) -> AttributedString {
        AttributedString("\u{2009}\(text)\u{2009}")
    }
}

/// "Will save as": the title and where it's going.
private struct WillSaveCard: View {
    let parse: VoiceParse

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Will save as")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.ink2)
            Text(parse.title.isEmpty ? "…" : parse.title)
                .font(.headline)
            HStack(spacing: 6) {
                if let date = parse.date {
                    chip("Later · \(ReminderFormatter().label(for: date, now: .now))", icon: "clock",
                         foreground: Theme.orangeText, background: Theme.orangeTint)
                }
                if let project = parse.projectName {
                    chip(project, icon: "folder", foreground: Theme.purple, background: Theme.purple.opacity(0.12))
                }
                if parse.date == nil && parse.projectName == nil {
                    if parse.isSomeday {
                        chip("Someday", icon: "archivebox", foreground: Theme.ink2, background: Theme.fill)
                    } else {
                        chip("Inbox", icon: nil, foreground: Theme.ink2, background: Theme.fill)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.bg, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func chip(_ title: String, icon: String?, foreground: Color, background: Color) -> some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
            }
            Text(title)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(foreground)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(background, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

private struct Waveform: View {
    let levels: [Float]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                Capsule()
                    .fill(Theme.blue)
                    .frame(width: 4)
                    .frame(maxHeight: .infinity)
                    .scaleEffect(y: CGFloat(max(0.15, level)), anchor: .center)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: levels)
    }
}

/// 10a: microphone or speech access is off.
struct MicDeniedSheet: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "mic.slash.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Theme.red)
                .frame(width: 60, height: 60)
                .background(Theme.red.opacity(0.12), in: Circle())
                .accessibilityHidden(true)
            Text("Catch can't use the mic")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("Microphone access is off for Catch. Turn it on in iOS Settings to talk, or type for now.")
                .font(.subheadline)
                .foregroundStyle(Theme.ink2)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            VStack(spacing: 10) {
                Button {
                    model.sheet = nil
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Open iOS Settings")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Theme.blue, in: Capsule())
                }
                Button {
                    model.typeInstead()
                } label: {
                    Label("Type Instead", systemImage: "keyboard")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.blue)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Theme.blueTint, in: Capsule())
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding(EdgeInsets(top: 30, leading: 24, bottom: 20, trailing: 24))
        .fittedSheet(showsHandle: false, background: Theme.card)
    }
}

/// 10b: the recognizer wasn't sure. Fix what it heard, try again, or drop it.
/// Nothing is saved until the user chooses.
struct VoiceRetrySheet: View {
    @Environment(AppModel.self) private var model
    @State private var text: String
    private let heard: String
    @ScaledMetric(relativeTo: .title) private var textSize: CGFloat = 26

    init(heard: String) {
        self.heard = heard
        _text = State(initialValue: heard)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Didn't catch all of that")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.orangeText)

            TextField("What did you say?", text: $text, axis: .vertical)
                .font(.system(size: textSize, weight: .semibold))
                .lineLimit(1...4)
                .submitLabel(.done)
                // Return saves rather than adding a line.
                .onChange(of: text) { _, new in
                    guard new.contains("\n") else { return }
                    text = new.replacingOccurrences(of: "\n", with: "")
                    model.saveSpoken(text)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text("It was hard to hear. Fix what's missing, or try again. Nothing is saved until you choose.")
                .font(.subheadline)
                .foregroundStyle(Theme.ink2)
                .lineSpacing(2)

            HStack(spacing: 10) {
                Button {
                    model.sheet = nil
                    model.flash("Hold + to try again", undo: false)
                } label: {
                    Label("Try Again", systemImage: "mic.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.blue)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Theme.blueTint, in: Capsule())
                }
                Button {
                    model.saveSpoken(text)
                } label: {
                    Text(text == heard ? "Save as Is" : "Save")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Theme.blue, in: Capsule())
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 6)

            Button("Discard", role: .destructive) { model.sheet = nil }
                .font(.subheadline)
                .foregroundStyle(Theme.red)
                .frame(maxWidth: .infinity, minHeight: 44)
                .buttonStyle(.plain)
        }
        .padding(EdgeInsets(top: 24, leading: 24, bottom: 16, trailing: 24))
        .fittedSheet(showsHandle: false, background: Theme.card)
        .interactiveDismissDisabled()
    }
}

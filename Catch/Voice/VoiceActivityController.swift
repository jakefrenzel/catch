import ActivityKit
import Foundation

/// 11g: one listening session started from the Action button. Listens with the
/// app's speech input, mirrors the transcript into a Live Activity, saves when
/// the speaker goes quiet (or taps Save), then shows where it went with Undo.
@MainActor
final class VoiceActivityController {
    /// Quiet this long after speech ends the session.
    static let silence: TimeInterval = 2
    /// Nothing heard this long ends it too.
    static let nothingHeard: TimeInterval = 8
    static let maximum: TimeInterval = 30

    private let model: AppModel
    private var activity: Activity<VoiceActivityAttributes>?
    private var monitor: Task<Void, Never>?

    init(model: AppModel) {
        self.model = model
    }

    var isRunning: Bool { activity != nil }

    func start() async {
        guard !isRunning, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // The background can't show permission prompts; the app asks on first use instead.
        guard model.voice.permission() == .allowed else { return }
        do {
            try model.voice.start(language: model.settings.voiceLanguage)
            activity = try Activity.request(
                attributes: VoiceActivityAttributes(),
                content: ActivityContent(state: .listening(model.parseVoice("")), staleDate: nil))
        } catch {
            model.voice.cancel()
            return
        }
        model.haptic(.medium)
        monitor = Task { [weak self] in await self?.watch() }
    }

    /// Stops listening and saves: to Later when a time was heard, otherwise Inbox.
    func finish() async {
        guard let activity else { return }
        monitor?.cancel()
        monitor = nil
        let result = await model.voice.stop()
        let saved = ShortcutActions.catchThought(result.transcript, store: model.store)
        let state: VoiceActivityAttributes.ContentState = saved.map {
            .saved(title: $0.title, destination: $0.destination)
        } ?? .nothingHeard
        await activity.end(ActivityContent(state: state, staleDate: nil),
                           dismissalPolicy: .after(.now.addingTimeInterval(8)))
        self.activity = nil
        if saved != nil { model.haptic(.success) }
    }

    /// After Undo: take the confirmation down straight away.
    func endNow() async {
        for activity in Activity<VoiceActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        activity = nil
    }

    private func watch() async {
        let started = Date.now
        var lastText = ""
        var lastChange = Date.now
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(400))
            let text = model.voice.transcript
            if text != lastText {
                lastText = text
                lastChange = .now
                await activity?.update(ActivityContent(state: .listening(model.parseVoice(text)), staleDate: nil))
            }
            let quiet = Date.now.timeIntervalSince(lastChange)
            let done = (!text.isEmpty && quiet >= Self.silence)
                || (text.isEmpty && quiet >= Self.nothingHeard)
                || Date.now.timeIntervalSince(started) >= Self.maximum
            if done {
                await finish()
                return
            }
        }
    }
}

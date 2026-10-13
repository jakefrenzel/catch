import ActivityKit
import Foundation
import UIKit

/// 11g: one listening session started from the Action button. Starts a Live
/// Activity, listens with the app's speech input, mirrors the transcript into
/// the activity, saves when the speaker goes quiet (or taps Save), then shows
/// where it went with Undo for a few seconds.
@MainActor
final class VoiceActivityController {
    enum StartFailure: Error {
        case busy, liveActivitiesOff, needsPermission, unavailable
    }

    /// Quiet this long after speech ends the session.
    static let silence: TimeInterval = 2
    /// Nothing heard this long ends it too.
    static let nothingHeard: TimeInterval = 8
    static let maximum: TimeInterval = 30
    /// How long the "Saved" confirmation stays up.
    static let confirmation: TimeInterval = 6

    private let model: AppModel
    private var activity: Activity<VoiceActivityAttributes>?
    private var monitor: Task<Void, Never>?
    private var isFinishing = false

    init(model: AppModel) {
        self.model = model
    }

    var isRunning: Bool { activity != nil }

    func start() async throws {
        // Anything left from a session that never finished (the app was killed) goes first.
        if activity == nil { await endAll() }
        guard !isRunning, !model.isListening else { throw StartFailure.busy }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { throw StartFailure.liveActivitiesOff }
        // The background can't show permission prompts; the app asks on first use.
        guard model.voice.permission() == .allowed else { throw StartFailure.needsPermission }

        // The Live Activity comes first: background recording is only allowed while one is up.
        let activity: Activity<VoiceActivityAttributes>
        do {
            activity = try Activity.request(
                attributes: VoiceActivityAttributes(),
                content: ActivityContent(state: .listening(model.parseVoice("", includeProjects: false)), staleDate: nil))
        } catch {
            throw StartFailure.liveActivitiesOff
        }
        do {
            try model.voice.start(language: model.settings.voiceLanguage)
        } catch {
            await activity.end(nil, dismissalPolicy: .immediate)
            throw StartFailure.unavailable
        }
        self.activity = activity
        model.isBackgroundListening = true
        model.haptic(.medium)
        monitor = Task { [weak self] in await self?.watch() }
    }

    /// Stops listening and saves: to Later when a time was heard, otherwise Inbox.
    func finish() async {
        guard !isFinishing else { return }
        guard let activity else {
            // A Save tap on a leftover activity from before a relaunch.
            await endAll()
            return
        }
        isFinishing = true
        defer { isFinishing = false }
        monitor?.cancel()
        monitor = nil
        // An auto-save on silence has no intent keeping the app running; ask for
        // time to save, schedule the reminder and take the banner down.
        let background = UIApplication.shared.beginBackgroundTask(withName: "Catch save")

        let shown = model.voice.transcript
        let result = model.keepingWhatWasShown(await model.voice.stop(), shown: shown)
        model.isBackgroundListening = false
        let failures = model.store.saveFailures
        let saved = ShortcutActions.catchThought(result.transcript, store: model.store)
        let saveFailed = model.store.saveFailures != failures
        let state: VoiceActivityAttributes.ContentState = saved.map {
            .saved(title: $0.title, destination: $0.destination, itemID: $0.itemID)
        } ?? (saveFailed ? .saveFailed : .nothingHeard)
        self.activity = nil
        if saved != nil { model.haptic(.success) }
        if saveFailed { model.haptic(.warning) }

        // Update rather than end, so the confirmation and Undo show in the Dynamic
        // Island too; then take it down after a few seconds. (If iOS suspends the
        // app first, the next session clears it.)
        let content = ActivityContent(state: state, staleDate: .now.addingTimeInterval(Self.confirmation))
        await activity.update(content)
        await model.syncReminders()
        Task {
            try? await Task.sleep(for: .seconds(Self.confirmation))
            await activity.end(content, dismissalPolicy: .immediate)
            UIApplication.shared.endBackgroundTask(background)
        }
    }

    /// After Undo: take the confirmation down straight away.
    func endNow() async {
        await endAll()
    }

    private func endAll() async {
        for activity in Activity<VoiceActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        activity = nil
        model.isBackgroundListening = false
    }

    private func watch() async {
        let started = Date.now
        var lastText = ""
        var lastChange = Date.now
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(400))
            // Save may have been tapped while this was asleep.
            guard !Task.isCancelled, !isFinishing else { return }
            let text = model.voice.transcript
            if text != lastText {
                lastText = text
                lastChange = .now
                await activity?.update(ActivityContent(
                    state: .listening(model.parseVoice(text, includeProjects: false)), staleDate: nil))
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

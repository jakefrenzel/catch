import Foundation
import Observation

/// UI state shared across screens (tab, toast, Up first skips, Focus) and the
/// user-facing versions of store actions: each one plays its haptic and shows
/// its toast.
@Observable
@MainActor
final class AppModel {
    enum Tab: Hashable, CaseIterable {
        case today, inbox, someday
    }

    struct Toast: Identifiable, Equatable {
        let id = UUID()
        let message: String
        let canUndo: Bool
    }

    let store: CatchStore
    let settingsStore: SettingsStore

    var tab: Tab = .today
    var upFirst = UpFirst()
    /// The Up first suggestion open in Focus.
    var focus: UpFirstCandidate?
    var toast: Toast?
    /// The Up first card on Today has scrolled out of view.
    var upFirstCardScrolledAway = false

    private var toastTask: Task<Void, Never>?

    init(store: CatchStore, settingsStore: SettingsStore) {
        self.store = store
        self.settingsStore = settingsStore
    }

    var settings: CatchSettings { settingsStore.settings }

    /// Pinned Up first bar: shown when the card isn't on screen.
    var showsPinnedUpFirst: Bool {
        focus == nil && (tab != .today || upFirstCardScrolledAway)
    }

    // MARK: - Items

    func toggleDone(_ item: Item) {
        let done = !item.isDone
        store.setDone(item, done)
        if done {
            haptic(.success)
            flash("Done: \(item.text)", undo: true)
        }
    }

    func toggleDone(_ step: Step) {
        let done = !step.isDone
        store.setDone(step, done)
        if done {
            haptic(.success)
            flash("Done: \(step.text)", undo: true)
        }
    }

    /// Left swipe on a Now row.
    func sendToLater(_ item: Item) {
        // TODO: open the Remind sheet once it exists. Until then, use the default time.
        store.move(item, to: .later)
        haptic(.light)
        flash("Moved to Later", undo: true)
    }

    /// Left swipe on a Later row.
    func bringToNow(_ item: Item) {
        switch store.move(item, to: .now) {
        case .moved:
            flash("Moved to Now", undo: true)
        case .nowIsFull:
            // TODO: open the Swap sheet once it exists.
            haptic(.warning)
            flash("Now is full (\(settings.maxNow)). Move something out first", undo: false)
        }
    }

    func setExpanded(_ project: Project, _ expanded: Bool) {
        store.setExpanded(project, expanded)
    }

    // MARK: - Up first

    func skipUpFirst(in candidates: [UpFirstCandidate]) {
        upFirst.skip(in: candidates)
    }

    func complete(_ candidate: UpFirstCandidate) {
        store.complete(candidate)
        haptic(.success)
        flash("Done: \(candidate.title)", undo: true)
    }

    func startFocus(on candidate: UpFirstCandidate) {
        focus = candidate
    }

    func finishFocus() {
        guard let candidate = focus else { return }
        focus = nil
        complete(candidate)
    }

    /// "Not Now" in Focus skips the suggestion.
    func skipFocus(in candidates: [UpFirstCandidate]) {
        focus = nil
        upFirst.skip(in: candidates)
    }

    // MARK: - Settings shortcuts

    func turnOnNotifications() {
        // TODO: request notification permission once reminders are scheduled.
        settingsStore.settings.notifications = true
        flash("Reminders are on", undo: false)
    }

    // MARK: - Toasts and haptics

    func flash(_ message: String, undo: Bool) {
        toastTask?.cancel()
        toast = Toast(message: message, canUndo: undo && store.canUndo)
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3.2))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    func undo() {
        toastTask?.cancel()
        toast = nil
        store.undo()
    }

    /// Placeholder for screens that aren't built yet.
    func notBuiltYet(_ name: String) {
        flash("\(name) isn't built yet", undo: false)
    }

    func haptic(_ haptic: Haptic) {
        guard settings.haptics else { return }
        haptic.play()
    }
}

extension UpFirstCandidate: Identifiable {
    var id: UUID { key }
}

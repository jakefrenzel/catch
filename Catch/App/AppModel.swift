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

    /// Sheets opened from list actions. Capture has its own flag because it opens from +.
    enum Sheet: Identifiable {
        case edit(Item)
        case remind(Item)
        case swap(incoming: Item)
        case newProject
        case settings

        var id: String {
            switch self {
            case .edit(let item): return "edit-\(item.id)"
            case .remind(let item): return "remind-\(item.id)"
            case .swap(let item): return "swap-\(item.id)"
            case .newProject: return "new-project"
            case .settings: return "settings"
            }
        }
    }

    struct Toast: Identifiable, Equatable {
        let id = UUID()
        let message: String
        let canUndo: Bool
    }

    let store: CatchStore
    let settingsStore: SettingsStore

    var tab: Tab = .today
    var isCaptureOpen = false
    var sheet: Sheet?
    /// Today's navigation stack: empty, or the open Project Detail.
    var projectPath: [Project] = []
    var upFirst = UpFirst()
    /// The Up first suggestion open in Focus.
    var focus: UpFirstCandidate?
    var toast: Toast?
    /// The Up first card on Today has scrolled out of view.
    var upFirstCardScrolledAway = false
    /// The time the screens show. Refreshed every 30 s and when the app comes forward.
    var now = Date.now
    /// Debug and screenshots: show the evening wrap-up regardless of the time.
    var forceEvening = false

    private var toastTask: Task<Void, Never>?
    /// Set while "Created X" can be undone, so Undo can close its detail screen first.
    private var undoableNewProject: Project?

    init(store: CatchStore, settingsStore: SettingsStore) {
        self.store = store
        self.settingsStore = settingsStore
    }

    var settings: CatchSettings { settingsStore.settings }

    /// Pinned Up first bar: shown when the card isn't on screen, hidden under sheets.
    var showsPinnedUpFirst: Bool {
        focus == nil && !isCaptureOpen && sheet == nil && !isEvening
            && (tab != .today || upFirstCardScrolledAway || !projectPath.isEmpty)
    }

    // MARK: - Day

    var isEvening: Bool {
        forceEvening || WrapUp.isEvening(now: now, settings: settings, calendar: store.calendar)
    }

    var isDayFinished: Bool {
        guard let finished = settingsStore.dayFinishedOn else { return false }
        return store.calendar.isDate(finished, inSameDayAs: now)
    }

    /// Updates the clock. The first time it sees a new day, items moved to
    /// tomorrow come back with "Carried over from last night".
    func refreshClock() {
        now = store.currentDate()
        let today = store.calendar.startOfDay(for: now)
        if let last = settingsStore.lastActiveDay, last < today {
            store.carryOverFromLastNight()
        }
        if settingsStore.lastActiveDay != today {
            settingsStore.lastActiveDay = today
        }
    }

    /// The evening card's Finish: moves what's left to tomorrow and closes the day.
    func finishDay() {
        now = store.currentDate()
        let moved = store.moveAllToTomorrow()
        settingsStore.dayFinishedOn = store.calendar.startOfDay(for: now)
        haptic(.success)
        flash(moved > 0 ? "Day finished. \(moved) moved to tomorrow" : "Day finished", undo: moved > 0)
    }

    func moveAllToTomorrow() {
        let moved = store.moveAllToTomorrow()
        guard moved > 0 else { return }
        flash("Moved \(moved) to tomorrow", undo: true)
    }

    func moveToTomorrow(_ item: Item) {
        store.moveToTomorrow(item)
        flash("Moved to tomorrow", undo: true)
    }

    // MARK: - Capture

    /// Saves a new item and says where it went. Returns false for empty text.
    @discardableResult
    func capture(_ text: String, to list: ListKind, remindAt: Date? = nil) -> Bool {
        guard let result = store.capture(text, to: list, remindAt: remindAt) else { return false }
        if result.redirectedToInbox {
            haptic(.warning)
            flash("Now is full. Saved to Inbox", undo: true)
        } else {
            flash("Saved to \(result.item.list.title)", undo: true)
        }
        return true
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

    /// Moves an item between lists from a swipe, a sort button or "Move to Now".
    /// Later asks when (Remind sheet); a full Now asks what to swap out.
    func move(_ item: Item, to list: ListKind) {
        if list == .later {
            openReminder(for: item)
            return
        }
        switch store.move(item, to: list) {
        case .moved:
            flash("Moved to \(list.title)", undo: true)
        case .nowIsFull:
            haptic(.warning)
            sheet = .swap(incoming: item)
        }
    }

    func openEditor(for item: Item) {
        sheet = .edit(item)
    }

    /// Saves the Edit sheet. The list picker already blocks a full Now, so
    /// `.nowIsFull` only happens if Now filled up while the sheet was open.
    func saveEdit(_ item: Item, text: String, note: String?, list: ListKind) {
        switch store.edit(item, text: text, note: note, list: list) {
        case .moved:
            sheet = nil
            haptic(.light)
            flash("Saved", undo: true)
        case .nowIsFull:
            warnNowIsFull()
        }
    }

    /// Edit sheet's "Remind me" row: keep the edits, then pick the time.
    func saveEditAndPickTime(_ item: Item, text: String, note: String?) {
        store.edit(item, text: text, note: note, list: .later)
        sheet = .remind(item)
    }

    func deleteFromEditor(_ item: Item) {
        sheet = nil
        delete(item)
    }

    func warnNowIsFull() {
        haptic(.warning)
        flash("Now is full (\(settings.maxNow)). Move something out first", undo: false)
    }

    func openReminder(for item: Item) {
        sheet = .remind(item)
    }

    /// Saves from the Remind sheet. `label` names the choice in the toast.
    func setReminder(_ item: Item, _ reminder: ReminderTime, nudge: Bool, label: String) {
        store.setReminder(item, reminder, nudge: nudge)
        sheet = nil
        haptic(.light)
        flash("Reminder set: \(label)", undo: true)
    }

    func swap(incoming: Item, outgoing: Item) {
        store.swap(incoming: incoming, outgoing: outgoing)
        sheet = nil
        flash("Swapped. “\(outgoing.text)” went to Inbox", undo: true)
    }

    func delete(_ item: Item) {
        store.delete(item)
        haptic(.warning)
        flash("Deleted", undo: true)
    }

    func setExpanded(_ project: Project, _ expanded: Bool) {
        store.setExpanded(project, expanded)
    }

    // MARK: - Projects

    func openProject(_ project: Project) {
        tab = .today
        projectPath = [project]
    }

    func openNewProject() {
        sheet = .newProject
    }

    func openSettings() {
        sheet = .settings
    }

    /// Creates the project and opens it. Returns false (with a nudge) without a name.
    @discardableResult
    func createProject(from draft: ProjectDraft) -> Bool {
        guard let project = store.createProject(from: draft) else {
            haptic(.warning)
            flash("Give the project a name", undo: false)
            return false
        }
        sheet = nil
        haptic(.success)
        flash("Created \(project.name)", undo: true)
        undoableNewProject = project
        openProject(project)
        return true
    }

    @discardableResult
    func addStep(_ text: String, to project: Project) -> Bool {
        guard store.addStep(text, to: project) != nil else { return false }
        haptic(.light)
        flash("Added to \(project.name)", undo: true)
        return true
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
        undoableNewProject = nil
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
        // Undoing "Created X" deletes X; leave its screen before the model goes away.
        if let project = undoableNewProject, projectPath.contains(project) {
            projectPath.removeAll()
        }
        undoableNewProject = nil
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

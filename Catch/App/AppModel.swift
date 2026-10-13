import Foundation
import Observation
import SwiftData
import UIKit
import WidgetKit

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
        /// 10a: the mic or speech recognition is off.
        case micDenied
        /// 10b: what was heard, to fix before saving.
        case voiceRetry(String)
        /// 8a step 3, asking about reminders for the first item.
        case onboardingPermission(Date)

        var id: String {
            switch self {
            case .edit(let item): return "edit-\(item.id)"
            case .remind(let item): return "remind-\(item.id)"
            case .swap(let item): return "swap-\(item.id)"
            case .newProject: return "new-project"
            case .settings: return "settings"
            case .micDenied: return "mic-denied"
            case .voiceRetry(let text): return "voice-retry-\(text)"
            case .onboardingPermission: return "onboarding-permission"
            }
        }
    }

    /// 8a: first launch walks through one spoken capture.
    enum OnboardingStep: Equatable {
        case welcome
        /// 1 of 3: hold + and talk.
        case hold
        /// 2 of 3: listening, waiting to hear a time.
        case talk
        /// 3 of 3: the reminders question.
        case permission
    }

    struct Toast: Identifiable, Equatable {
        let id = UUID()
        let message: String
        let canUndo: Bool
        /// The store's undo version when shown; Undo only runs if it still matches.
        var undoVersion: Int?
    }

    let store: CatchStore
    let settingsStore: SettingsStore

    var tab: Tab = .today
    var onboarding: OnboardingStep?
    /// A mic or capture link that came in during step 3, run once the question is answered.
    private var linkAfterOnboarding: URL?
    var isCaptureOpen = false
    var sheet: Sheet?
    /// Today's navigation stack: empty, or the open Project Detail.
    var projectPath: [Project] = []
    var upFirst = UpFirst()
    /// The Up first suggestion open in Focus.
    var focus: UpFirstCandidate?
    /// Focus opened from Up first's Start, not picked out of order.
    private(set) var focusIsSuggestion = false
    var toast: Toast?
    /// The Up first card on Today has scrolled out of view.
    var upFirstCardScrolledAway = false
    /// What Up first suggests right now (RootView keeps it current); nil when all clear.
    var currentUpFirst: UUID? {
        didSet {
            // Something else is up first, so a swiped-away bar comes back.
            if let currentUpFirst, let hidden = settingsStore.hiddenPinnedUpFirst, hidden != currentUpFirst {
                settingsStore.hiddenPinnedUpFirst = nil
            }
        }
    }
    /// The time the screens show. Refreshed every 30 s and when the app comes forward.
    var now = Date.now
    /// Debug and screenshots: show the evening wrap-up regardless of the time.
    var forceEvening = false
    /// A save failed during the current update; its toast stays up over any other.
    @ObservationIgnored private var saveJustFailed = false

    private var toastTask: Task<Void, Never>?
    /// Set while "Created X" can be undone, so Undo can close its detail screen first.
    private var undoableNewProject: Project?

    let notifications: NotificationScheduling
    let voice: VoiceInput
    let location: LocationService
    /// Settings' navigation stack (Places and its editor).
    var settingsPath: [SettingsRoute] = []
    /// + is held and Catch is listening.
    var isListening = false
    /// Waiting for the final transcript after letting go.
    private var isStoppingListening = false
    /// The Action button session is using the microphone.
    var isBackgroundListening = false
    /// Listening was started by a tap (Lock Screen mic, control), so there's no
    /// finger to lift: the voice sheet shows a Save button instead.
    var isTapToTalk = false
    private(set) var listeningStartedAt = Date.now
    private var syncTask: Task<Void, Never>?
    private var syncChain: Task<Void, Never>?
    /// Cancel was asked for while the last capture was still being finished.
    private var discardPendingStop = false

    init(store: CatchStore, settingsStore: SettingsStore, notifications: NotificationScheduling,
         voice: VoiceInput? = nil) {
        self.store = store
        self.settingsStore = settingsStore
        self.notifications = notifications
        self.voice = voice ?? SpeechVoiceInput()
        self.location = LocationService()
        // The store's clock, so tests don't depend on when they run.
        self.now = store.currentDate()
        store.onChange = { [weak self] in self?.scheduleReminderSync() }
        store.onSaveFailure = { [weak self] in
            guard let self else { return }
            haptic(.warning)
            flash("Couldn't save that change. Try again.", undo: false)
            // Whatever the failed change goes on to say ("Saved to Now") mustn't cover this.
            saveJustFailed = true
            Task { self.saveJustFailed = false }
        }
    }

    var settings: CatchSettings { settingsStore.settings }

    /// Swiped away, and the same thing is still up first.
    var pinnedUpFirstHidden: Bool {
        currentUpFirst != nil && settingsStore.hiddenPinnedUpFirst == currentUpFirst
    }

    /// Pinned Up first bar: shown when the card isn't on screen, hidden under sheets.
    var showsPinnedUpFirst: Bool {
        settings.pinnedUpFirst && !pinnedUpFirstHidden
            && focus == nil && !isCaptureOpen && sheet == nil && !isEvening && !isListening && onboarding == nil
            && (tab != .today || upFirstCardScrolledAway || !projectPath.isEmpty)
    }

    /// Room the lists leave at the bottom: the tab bar, plus the pinned Up first bar
    /// unless it's turned off, swiped away, has nothing to show or the evening
    /// wrap-up has replaced it.
    var listBottomMargin: CGFloat {
        settings.pinnedUpFirst && currentUpFirst != nil && !pinnedUpFirstHidden && !isEvening ? 180 : 120
    }

    // MARK: - Day

    var isEvening: Bool {
        forceEvening || WrapUp.isEvening(now: now, settings: settings, calendar: store.calendar)
    }

    var isDayFinished: Bool {
        guard let finished = settingsStore.dayFinishedOn else { return false }
        return DayClock.day(of: finished, calendar: store.calendar) == DayClock.day(of: now, calendar: store.calendar)
    }

    /// Updates the clock. The first time it sees a new day, items moved to
    /// tomorrow come back with "Carried over from last night".
    func refreshClock() {
        now = store.currentDate()
        store.carryOverIfNewDay()
        store.promoteOverdueLaterItems()
    }

    /// The evening card's Finish: moves what's left to tomorrow and closes the day.
    func finishDay() {
        now = store.currentDate()
        let moved = store.moveAllToTomorrow()
        settingsStore.dayFinishedOn = now
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
        if result.item.list == .later {
            Task { await ensureNotificationPermission() }
        }
        return true
    }

    // MARK: - Voice

    // MARK: - First launch

    /// Shows the welcome screen on a fresh install. Anyone who already has
    /// items (an update, or demo data) skips it.
    func startOnboardingIfNeeded() {
        guard !settingsStore.hasOnboarded else { return }
        if store.allItems().isEmpty && store.projects().isEmpty {
            onboarding = .welcome
        } else {
            settingsStore.hasOnboarded = true
        }
    }

    func beginOnboarding() {
        tab = .today
        projectPath = []
        onboarding = .hold
    }

    func skipOnboarding() {
        onboarding = nil
        settingsStore.hasOnboarded = true
    }

    /// Settings → Replay the Tutorial. Keeps everything the user has.
    func replayOnboarding() {
        sheet = nil
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            onboarding = .welcome
        }
    }

    /// A plain tap on + during step 1.
    func tapCaptureDuringOnboarding() {
        flash("Hold it down to talk", undo: false)
    }

    /// Step 3's buttons. "Not Now" turns reminders off, so Today shows 10c. On a replay
    /// it leaves them as they were: the tutorial shouldn't switch off reminders already set.
    func finishOnboarding(allowReminders: Bool) async {
        let isReplay = settingsStore.hasOnboarded
        sheet = nil
        onboarding = nil
        settingsStore.hasOnboarded = true
        if allowReminders {
            let granted = await notifications.requestAuthorization()
            settingsStore.settings.notifications = granted
            flash(granted ? "Reminders are on" : "You can turn reminders on later", undo: false)
        } else if !isReplay {
            settingsStore.settings.notifications = false
            flash("You can turn reminders on later", undo: false)
        }
        await syncReminders()
        if let url = linkAfterOnboarding {
            linkAfterOnboarding = nil
            afterSheetsClose(true) { $0.handle(url) }
        }
    }

    /// Step 2 ends: saved only once a time was heard, otherwise back to step 1.
    private func finishOnboardingVoice(_ result: VoiceResult, saved: Bool) {
        let parse = parseVoice(result.transcript)
        guard saved, let date = parse.date, !parse.title.isEmpty else {
            onboarding = .hold
            if saved { flash("Keep holding until you’ve said the time", undo: false) }
            return
        }
        // Saved directly: step 3 asks about reminders before iOS does.
        if store.capture(parse.title, to: .later, remindAt: date) != nil {
            flash("Saved to Later", undo: false)
        }
        onboarding = .permission
        sheet = .onboardingPermission(date)
    }

    // MARK: - Voice

    /// Hold +: start listening, or explain why not.
    func startListening(tapToTalk: Bool = false) {
        // One listener at a time: not while the last capture is still saving,
        // and not while the Action button session is listening.
        guard !isListening, !isStoppingListening, !isBackgroundListening else { return }
        switch voice.permission() {
        case .denied:
            haptic(.warning)
            sheet = .micDenied
        case .notDetermined:
            Task {
                if await voice.requestPermission() {
                    flash("Hold + again to talk", undo: false)
                } else {
                    sheet = .micDenied
                }
            }
        case .allowed:
            do {
                try voice.start(language: settings.voiceLanguage)
                listeningStartedAt = .now
                isListening = true
                isTapToTalk = tapToTalk
                if onboarding == .hold { onboarding = .talk }
                haptic(.medium)
            } catch {
                flash("Listening isn't available right now", undo: false)
            }
        }
    }

    /// Let go of +. Dragging away first cancels without saving.
    func stopListening(save: Bool) async {
        guard isListening else { return }
        // Already finishing (a double tap on Save, or Cancel during the wait).
        guard !isStoppingListening else {
            if !save {
                discardPendingStop = true
                voice.cancel()
            }
            return
        }
        isTapToTalk = false
        guard save else {
            voice.cancel()
            isListening = false
            if onboarding == .talk { onboarding = .hold }
            return
        }
        isStoppingListening = true
        let shown = voice.transcript
        let result = keepingWhatWasShown(await voice.stop(), shown: shown)
        isStoppingListening = false
        isListening = false
        if discardPendingStop {
            discardPendingStop = false
            if onboarding == .talk { onboarding = .hold }
            return
        }
        if onboarding == .talk {
            finishOnboardingVoice(result, saved: true)
            return
        }
        saveVoice(result)
    }

    /// The sheet showed what was heard and said "Let go to save"; if the final
    /// transcript lost all of it, or the time, save what was shown instead.
    func keepingWhatWasShown(_ result: VoiceResult, shown: String) -> VoiceResult {
        let final = result.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let shown = shown.trimmingCharacters(in: .whitespacesAndNewlines)
        let lostEverything = final.isEmpty && !shown.isEmpty
        let lostTheTime = !shown.isEmpty && parseVoice(final).date == nil && parseVoice(shown).date != nil
        guard lostEverything || lostTheTime else { return result }
        return VoiceResult(transcript: shown, isUncertain: lostEverything ? false : result.isUncertain)
    }

    func saveVoice(_ result: VoiceResult) {
        let text = result.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            flash("Didn't hear anything. Hold + and talk.", undo: false)
            return
        }
        if result.isUncertain {
            sheet = .voiceRetry(text)
        } else {
            saveSpoken(text)
        }
    }

    /// Saves a spoken (or corrected) sentence where it says to go: Later at
    /// the time heard, a step in the project heard, Someday, or Inbox.
    @discardableResult
    func saveSpoken(_ text: String) -> Bool {
        let parse = parseVoice(text)
        guard !parse.title.isEmpty else {
            sheet = .voiceRetry(text)
            return false
        }
        if case .voiceRetry? = sheet { sheet = nil }
        switch parse.destination {
        case .later(let date):
            return capture(parse.title, to: .later, remindAt: date)
        case .projectStep(let id):
            if let project = store.projects().first(where: { $0.id == id }) {
                return addStep(parse.title, to: project)
            }
            return capture(parse.title, to: .inbox)
        case .someday:
            return capture(parse.title, to: .someday)
        case .inbox:
            return capture(parse.title, to: .inbox)
        }
    }

    /// `includeProjects` is off where saving ignores projects (Siri, the Action button),
    /// so the preview doesn't promise a project step that won't happen.
    func parseVoice(_ text: String, includeProjects: Bool = true) -> VoiceParse {
        VoiceParser.parse(text,
                          projects: includeProjects ? store.projects().map { .init(id: $0.id, name: $0.name) } : [],
                          afterWork: settings.afterWork,
                          now: store.currentDate(),
                          calendar: store.calendar)
    }

    /// 10a's Type Instead: swap the mic sheet for the Capture card.
    func typeInstead() {
        sheet = nil
        Task {
            // Let the sheet finish closing before the next one opens.
            try? await Task.sleep(for: .milliseconds(450))
            isCaptureOpen = true
        }
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

    /// Edit sheet's "Remind me" row: keep the edits, then pick the time. The item
    /// only moves to Later when the Remind sheet saves, so closing it leaves the
    /// item where it was and Undo takes it back there.
    func saveEditAndPickTime(_ item: Item, text: String, note: String?) {
        store.edit(item, text: text, note: note, list: item.list)
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
        Task {
            await ensureNotificationPermission()
            if case .place = reminder, !(await location.requestAccess()) {
                flash("Place reminders need Location. Turn it on in iOS Settings.", undo: false)
            }
        }
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

    // MARK: - Places

    func savePlace(_ place: Place?, name: String, address: String,
                   latitude: Double, longitude: Double, radius: Double) {
        store.savePlace(place, name: name, address: address,
                        latitude: latitude, longitude: longitude, radius: radius)
        haptic(.light)
        // Place reminders need location access; ask while the user is setting places up.
        Task { _ = await location.requestAccess() }
    }

    func removePlace(_ place: Place) {
        let name = place.name
        store.deletePlace(place)
        haptic(.warning)
        flash("Removed \(name)", undo: false)
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
            // A failed save has already said so.
            if !store.lastSaveFailed {
                haptic(.warning)
                flash("Give the project a name", undo: false)
            }
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

    /// Swiping the pinned bar down.
    func hidePinnedUpFirst() {
        settingsStore.hiddenPinnedUpFirst = currentUpFirst
        flash("Hidden until something else is up first", undo: false)
    }

    func skipUpFirst(in candidates: [UpFirstCandidate]) {
        upFirst.skip(in: candidates)
    }

    func complete(_ candidate: UpFirstCandidate) {
        store.complete(candidate)
        haptic(.success)
        flash("Done: \(candidate.title)", undo: true)
    }

    func startFocus(on candidate: UpFirstCandidate) {
        focusIsSuggestion = true
        focus = candidate
    }

    /// "Start Focus" on any open item or step, out of Up first's order.
    func startChosenFocus(_ candidate: UpFirstCandidate) {
        focusIsSuggestion = false
        guard sheet != nil else {
            focus = candidate
            return
        }
        sheet = nil
        Task {
            // Let the sheet finish closing before Focus covers the screen.
            try? await Task.sleep(for: .milliseconds(450))
            focus = candidate
        }
    }

    /// Edit sheet's "Start Focus": keep the edits, then open Focus on the item.
    func saveEditAndFocus(_ item: Item, text: String, note: String?, list: ListKind) {
        switch store.edit(item, text: text, note: note, list: list) {
        case .moved: startChosenFocus(.item(item))
        case .nowIsFull: warnNowIsFull()
        }
    }

    /// The line above the title in Focus: why it's suggested, or where it's from.
    func focusReason(for candidate: UpFirstCandidate) -> String {
        if focusIsSuggestion { return candidate.reason }
        switch candidate {
        case .item(let item): return "From \(item.list.title)"
        case .step(_, let project): return "In \(project.name)"
        }
    }

    func finishFocus() {
        guard let candidate = focus else { return }
        focus = nil
        complete(candidate)
    }

    /// "Not Now" in Focus skips the suggestion; on a chosen item it just closes.
    func skipFocus(in candidates: [UpFirstCandidate]) {
        focus = nil
        if focusIsSuggestion { upFirst.skip(in: candidates) }
    }

    // MARK: - Settings shortcuts

    /// "Turn On" on the Reminders-are-off banner.
    func turnOnNotifications() async {
        switch await notifications.permission() {
        case .allowed:
            settingsStore.settings.notifications = true
            flash("Reminders are on", undo: false)
        case .notDetermined:
            let granted = await notifications.requestAuthorization()
            settingsStore.settings.notifications = granted
            flash(granted ? "Reminders are on" : "Reminders stay off", undo: false)
        case .denied:
            // iOS won't ask again; send them to Settings.
            notifications.openSystemSettings()
        }
        await syncReminders()
    }

    /// Asks for permission the first time it's needed. If the answer is no,
    /// the Notifications setting turns off so Today shows the banner.
    func ensureNotificationPermission() async {
        guard settings.notifications else { return }
        switch await notifications.permission() {
        case .allowed:
            break
        case .notDetermined:
            if !(await notifications.requestAuthorization()) {
                settingsStore.settings.notifications = false
            }
        case .denied:
            settingsStore.settings.notifications = false
        }
        await syncReminders()
    }

    func settingsChanged(from old: CatchSettings, to new: CatchSettings) {
        if new.notifications && !old.notifications {
            Task { await ensureNotificationPermission() }
        } else {
            scheduleReminderSync()
        }
    }

    // MARK: - Reminders

    /// Reschedules shortly after changes settle, so a burst of edits makes one pass.
    func scheduleReminderSync() {
        syncTask?.cancel()
        syncTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await self?.syncReminders()
        }
    }

    /// Reschedules every alert. Runs one at a time, so a slow pass can't re-add
    /// alerts after a newer pass cleared them.
    func syncReminders() async {
        let previous = syncChain
        let next = Task { @MainActor [weak self] in
            await previous?.value
            await self?.performReminderSync()
        }
        syncChain = next
        await next.value
    }

    private func performReminderSync() async {
        var planned: [PlannedReminder] = []
        if settings.notifications {
            let now = store.currentDate()
            planned = ReminderPlanner.plan(items: store.allItems(), now: now, nudgeDefault: settings.nudgeDefault)
            planned += ReminderPlanner.wrapUp(openInNow: store.openNowItems.count, settings: settings,
                                              dayFinished: isDayFinished, now: now, calendar: store.calendar)
        }
        await notifications.replacePending(with: planned)
        // The same changes can change what the widgets show.
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// catch://today, catch://inbox, catch://voice, catch://capture from widgets.
    func handle(_ url: URL) {
        guard url.scheme == "catch" else { return }
        let host = url.host()
        // Closing step 3's sheet would leave the tutorial unfinished and the app disabled.
        if onboarding == .permission && (host == "voice" || host == "capture") {
            linkAfterOnboarding = url
            return
        }
        let hadSheet = sheet != nil || focus != nil || isCaptureOpen
        if host == "voice" || host == "capture" {
            // Whatever was open gives way to the capture.
            sheet = nil
            focus = nil
            isCaptureOpen = false
        }
        switch host {
        case "inbox":
            projectPath = []
            tab = .inbox
        case "voice":
            tab = .today
            afterSheetsClose(hadSheet) { $0.startListening(tapToTalk: true) }
        case "capture":
            afterSheetsClose(hadSheet) { $0.isCaptureOpen = true }
        default:
            tab = .today
        }
    }

    /// Runs `action` now, or once a closing sheet has finished animating away.
    private func afterSheetsClose(_ wait: Bool, _ action: @escaping (AppModel) -> Void) {
        guard wait else { return action(self) }
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            action(self)
        }
    }

    /// The app went to the background mid-listen (a call, switching apps):
    /// drop the half-finished capture rather than leave the sheet stuck.
    func appMovedToBackground() {
        guard isListening else { return }
        Task { await stopListening(save: false) }
    }

    /// Done or In 1 Hour on an alert, or a tap on it.
    func handleNotificationAction(_ action: String, itemID: UUID) async {
        refreshClock()
        guard let item = store.allItems().first(where: { $0.id == itemID }) else { return }
        switch action {
        case NotificationAction.done:
            store.setDone(item, true)
        case NotificationAction.snooze:
            store.snooze(item)
        default:
            tab = .today
            projectPath = []
            return
        }
        // Run from a background launch: reschedule (dropping the nudge) and
        // refresh widgets before iOS suspends the app again.
        await syncReminders()
    }

    // MARK: - Toasts and haptics

    func flash(_ message: String, undo: Bool) {
        guard !saveJustFailed else { return }
        toastTask?.cancel()
        undoableNewProject = nil
        toast = Toast(message: message, canUndo: undo && store.canUndo,
                      undoVersion: undo ? store.undoVersion : nil)
        // VoiceOver hears the toast, and assistive-tech users get time to reach Undo.
        let assisted = UIAccessibility.isVoiceOverRunning || UIAccessibility.isSwitchControlRunning
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .announcement,
                                 argument: toast?.canUndo == true ? "\(message). Undo available." : message)
        }
        let duration: Double = assisted ? 10 : 3.2
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    /// Swiping the toast up.
    func dismissToast() {
        toastTask?.cancel()
        toast = nil
    }

    func undo() {
        toastTask?.cancel()
        let version = toast?.undoVersion
        toast = nil
        // Only reverse what the toast described; a newer change may have replaced it.
        guard let version, version == store.undoVersion else { return }
        // Undo can remove what an open sheet is working on.
        sheet = nil
        // Undoing "Created X" deletes X; leave its screen before the model goes away.
        if let project = undoableNewProject, projectPath.contains(project) {
            projectPath.removeAll()
        }
        undoableNewProject = nil
        store.undo()
        // Undoing "Saved to Now" deletes the item, which Focus may be showing.
        closeWhatWasDeleted()
    }

    /// After a delete the screen didn't ask for (an undo, Siri or the Live Activity), close
    /// Focus or a sheet still showing what's gone, before anything reads the deleted model.
    func closeWhatWasDeleted() {
        if let focus, focus.isGone { self.focus = nil }
        if let sheet, sheet.isGone { self.sheet = nil }
    }

    func haptic(_ haptic: Haptic) {
        guard settings.haptics else { return }
        haptic.play()
    }
}

extension UpFirstCandidate: Identifiable {
    var id: UUID { key }
}

private extension PersistentModel {
    /// Deleted, saved or not. Safe to ask of a model that's gone.
    var isGone: Bool { modelContext == nil || isDeleted }
}

private extension UpFirstCandidate {
    var isGone: Bool {
        switch self {
        case .item(let item): return item.isGone
        case .step(let step, let project): return step.isGone || project.isGone
        }
    }
}

private extension AppModel.Sheet {
    var isGone: Bool {
        switch self {
        case .edit(let item), .remind(let item), .swap(let item): return item.isGone
        case .newProject, .settings, .micDenied, .voiceRetry, .onboardingPermission: return false
        }
    }
}

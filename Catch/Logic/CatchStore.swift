import Foundation
import OSLog
import SwiftData

/// All the rules for moving things between lists, enforcing the Now limit,
/// projects and the evening wrap-up. Views call this rather than editing models directly.
///
/// Every user action can be undone from its toast: each mutating method records
/// how to reverse itself, and `undo()` reverses the most recent one.
@MainActor
final class CatchStore {
    struct CaptureResult {
        let item: Item
        let requested: ListKind

        /// Asked for Now but Now was full, so it went to Inbox.
        var redirectedToInbox: Bool { requested == .now && item.list == .inbox }
    }

    enum MoveResult: Equatable {
        case moved
        /// Now is full. Show the Swap sheet.
        case nowIsFull
    }

    let context: ModelContext
    let settingsStore: SettingsStore
    let calendar: Calendar
    private let now: () -> Date
    private var undoAction: (() -> Void)? {
        didSet { undoVersion += 1 }
    }
    /// Changes whenever the pending undo does, so a toast can tell whether its
    /// action is still the one Undo would reverse.
    private(set) var undoVersion = 0
    /// Called after every save, so reminders can be rescheduled.
    var onChange: (() -> Void)?
    private let log = Logger(subsystem: "com.jakefrenzel.catch", category: "store")

    init(context: ModelContext,
         settingsStore: SettingsStore,
         calendar: Calendar = .autoupdatingCurrent,
         now: @escaping () -> Date = Date.init) {
        self.context = context
        self.settingsStore = settingsStore
        self.calendar = calendar
        self.now = now
    }

    var settings: CatchSettings { settingsStore.settings }

    /// The store's clock, so screens and rules agree on the time (and tests can fake it).
    func currentDate() -> Date { now() }

    // MARK: - Queries

    /// All items, oldest capture first.
    func allItems() -> [Item] {
        fetch(FetchDescriptor<Item>(sortBy: [SortDescriptor(\Item.capturedAt)]))
    }

    func items(in list: ListKind) -> [Item] {
        allItems().filter { $0.list == list }
    }

    func projects() -> [Project] {
        fetch(FetchDescriptor<Project>(sortBy: [SortDescriptor(\Project.sortOrder)]))
    }

    func places() -> [Place] {
        fetch(FetchDescriptor<Place>(sortBy: [SortDescriptor(\Place.name)]))
    }

    var openNowItems: [Item] { allItems().filter(\.isOpenInNow) }

    var isNowFull: Bool { openNowItems.count >= settings.maxNow }

    func upFirstCandidates() -> [UpFirstCandidate] {
        UpFirst.candidates(items: allItems(), projects: projects(), includeSteps: settings.upFirstIncludesSteps)
    }

    /// When a Later item with no chosen time comes back: the next "After work" time.
    func defaultLaterTime() -> Date {
        settings.afterWork.next(after: now(), calendar: calendar)
    }

    // MARK: - Undo

    var canUndo: Bool { undoAction != nil }

    /// Reverses the most recent action. Only one level, like the toast it backs.
    func undo() {
        guard let action = undoAction else { return }
        undoAction = nil
        action()
        save()
    }

    // MARK: - Capture and moving

    /// Saves a new item. Empty text is ignored. Asking for a full Now puts it in Inbox.
    @discardableResult
    func capture(_ text: String, to list: ListKind, remindAt: Date? = nil) -> CaptureResult? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let destination: ListKind = (list == .now && isNowFull) ? .inbox : list
        let item = Item(text: trimmed, list: destination, capturedAt: now())
        switch destination {
        case .now: item.reason = Reason.justAdded
        case .later: item.reminder = .date(remindAt ?? defaultLaterTime())
        case .inbox, .someday: break
        }
        context.insert(item)
        undoAction = { [context] in context.delete(item) }
        save()
        return CaptureResult(item: item, requested: list)
    }

    /// Moves an item to another list. Moving into a full Now does nothing and
    /// returns `.nowIsFull` so the caller can offer a swap.
    @discardableResult
    func move(_ item: Item, to list: ListKind, remindAt: Date? = nil) -> MoveResult {
        let from = item.list
        guard list != from else { return .moved }
        if list == .now && isNowFull { return .nowIsFull }

        recordUndo(restoring: [item])
        applyMove(item, to: list, remindAt: remindAt)
        save()
        return .moved
    }

    /// Sends `outgoing` from Now back to Inbox and puts `incoming` in its place.
    func swap(incoming: Item, outgoing: Item) {
        recordUndo(restoring: [incoming, outgoing])
        outgoing.list = .inbox
        outgoing.reason = nil
        incoming.list = .now
        incoming.reason = Reason.swappedIn
        incoming.reminder = nil
        incoming.movedToTomorrow = false
        save()
    }

    /// Sets a reminder, which also moves the item to Later.
    /// `nudge` nil means "use the Settings default".
    func setReminder(_ item: Item, _ reminder: ReminderTime, nudge: Bool? = nil) {
        recordUndo(restoring: [item])
        item.list = .later
        item.reminder = reminder
        item.nudge = nudge
        item.reason = nil
        item.movedToTomorrow = false
        save()
    }

    /// Whether a missed reminder for this item gets a second alert.
    func nudges(_ item: Item) -> Bool { item.nudge ?? settings.nudgeDefault }

    /// Edits text and note. Empty text keeps the old title; an empty note is removed.
    func update(_ item: Item, text: String, note: String?) {
        recordUndo(restoring: [item])
        applyText(item, text: text, note: note)
        save()
    }

    /// The Edit sheet's save: text, note and list as one undoable change.
    /// Moving into a full Now changes nothing and returns `.nowIsFull`.
    @discardableResult
    func edit(_ item: Item, text: String, note: String?, list: ListKind) -> MoveResult {
        if list == .now && item.list != .now && isNowFull { return .nowIsFull }
        recordUndo(restoring: [item])
        applyText(item, text: text, note: note)
        if list != item.list {
            applyMove(item, to: list, remindAt: nil)
        }
        save()
        return .moved
    }

    func setDone(_ item: Item, _ done: Bool) {
        recordUndo(restoring: [item])
        item.completedAt = done ? now() : nil
        save()
    }

    func setDone(_ step: Step, _ done: Bool) {
        let previous = step.completedAt
        undoAction = { step.completedAt = previous }
        step.completedAt = done ? now() : nil
        save()
    }

    func complete(_ candidate: UpFirstCandidate) {
        switch candidate {
        case .item(let item): setDone(item, true)
        case .step(let step, _): setDone(step, true)
        }
    }

    func delete(_ item: Item) {
        let snapshot = ItemSnapshot(item)
        context.delete(item)
        undoAction = { [context] in context.insert(snapshot.recreate()) }
        save()
    }

    // MARK: - Evening wrap-up

    func moveToTomorrow(_ item: Item) {
        recordUndo(restoring: [item])
        item.movedToTomorrow = true
        item.movedToTomorrowAt = now()
        save()
    }

    /// "All to Tomorrow" / Finish. Returns how many items moved.
    @discardableResult
    func moveAllToTomorrow() -> Int {
        let open = openNowItems
        recordUndo(restoring: open)
        let moment = now()
        for item in open {
            item.movedToTomorrow = true
            item.movedToTomorrowAt = moment
        }
        save()
        return open.count
    }

    /// An ignored Later reminder comes into Now once its time (and nudge, if
    /// any) has passed, as long as Now has room. Not undoable; returns what moved.
    @discardableResult
    func promoteOverdueLaterItems() -> [Item] {
        let current = now()
        var promoted: [Item] = []
        for item in allItems() where item.list == .later && !item.isDone {
            guard case .date(let date)? = item.reminder else { continue }
            let due = date.addingTimeInterval(nudges(item) ? ReminderPlanner.nudgeDelay : 0)
            guard due <= current, !isNowFull else { continue }
            applyMove(item, to: .now, remindAt: nil)
            promoted.append(item)
        }
        // Leaves the pending undo alone: it only touches its own items.
        if !promoted.isEmpty { save() }
        return promoted
    }

    /// "In 1 Hour" on a reminder alert.
    func snooze(_ item: Item, by interval: TimeInterval = 60 * 60) {
        recordUndo(restoring: [item])
        item.list = .later
        item.reminder = .date(now().addingTimeInterval(interval))
        item.reason = nil
        save()
    }

    /// Once tomorrow comes (the day turns over at 4 AM), brings back what was
    /// moved to it, oldest first, up to the Now limit; anything beyond goes to
    /// Inbox so Now never overflows. Safe to call often. Not undoable.
    @discardableResult
    func carryOverIfNewDay() -> Int {
        let current = now()
        let returning = allItems().filter { WrapUp.isBackFromTomorrow($0, at: current, calendar: calendar) }
        guard !returning.isEmpty else { return 0 }
        undoAction = nil
        var room = max(0, settings.maxNow - openNowItems.count)
        for item in returning {
            item.movedToTomorrow = false
            item.movedToTomorrowAt = nil
            if room > 0 {
                item.reason = Reason.carriedOver
                room -= 1
            } else {
                item.list = .inbox
                item.reason = nil
            }
        }
        save()
        return returning.count
    }

    // MARK: - Projects

    /// Creates a project from the New Project sheet. Returns nil without a name.
    /// Inbox items used as steps leave the Inbox.
    @discardableResult
    func createProject(from draft: ProjectDraft) -> Project? {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }

        var resolved = draft.resolvedSteps()
        if resolved.isEmpty {
            resolved = [.init(text: ProjectDraft.placeholderStep, phase: Step.defaultPhase)]
        }

        let nextOrder = (projects().map(\.sortOrder).max() ?? -1) + 1
        let project = Project(name: name, sortOrder: nextOrder, createdAt: now())
        context.insert(project)
        let steps = resolved.enumerated().map { index, step in
            Step(text: step.text, phase: step.phase, sortOrder: index)
        }
        for step in steps { context.insert(step) }
        project.steps = steps

        let consumed = draft.inboxItems.map(ItemSnapshot.init)
        for item in draft.inboxItems { context.delete(item) }

        undoAction = { [context] in
            context.delete(project)
            for snapshot in consumed { context.insert(snapshot.recreate()) }
        }
        save()
        return project
    }

    /// Adds a step at the end of the project's current phase
    /// (the phase of the next step, or the last phase when everything is done).
    @discardableResult
    func addStep(_ text: String, to project: Project) -> Step? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var ordered = project.orderedSteps
        let phase = (project.nextStep ?? ordered.last)?.phase ?? Step.defaultPhase
        let insertAt = (ordered.lastIndex { $0.phase == phase }).map { $0 + 1 } ?? ordered.endIndex

        let step = Step(text: trimmed, phase: phase)
        context.insert(step)
        ordered.insert(step, at: insertAt)
        for (index, s) in ordered.enumerated() { s.sortOrder = index }
        project.steps = ordered

        undoAction = { [context] in
            project.steps?.removeAll { $0.id == step.id }
            context.delete(step)
        }
        save()
        return step
    }

    // MARK: - Places

    /// Creates a place (when `place` is nil) or updates one. Radius is kept to 100–300 m.
    @discardableResult
    func savePlace(_ place: Place?, name: String, address: String,
                   latitude: Double, longitude: Double, radius: Double) -> Place {
        let target: Place
        if let place {
            target = place
        } else {
            target = Place(name: "", address: "", latitude: latitude, longitude: longitude)
            context.insert(target)
        }
        target.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        target.address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        target.latitude = latitude
        target.longitude = longitude
        target.radiusMeters = min(max(radius, 100), 300)
        save()
        return target
    }

    /// Removes a place. Later items that were waiting on it fall back to the
    /// "After work" time rather than losing their reminder.
    func deletePlace(_ place: Place) {
        // A pending undo could still point at this place.
        undoAction = nil
        for item in allItems() where item.place?.id == place.id {
            item.reminder = item.list == .later ? .date(defaultLaterTime()) : nil
        }
        context.delete(place)
        save()
    }

    /// Shows or hides a project's steps on Today. Not an undoable action.
    func setExpanded(_ project: Project, _ expanded: Bool) {
        project.isExpanded = expanded
        save()
    }

    // MARK: - Private

    private func applyText(_ item: Item, text: String, note: String?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { item.text = trimmed }
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        item.note = trimmedNote.isEmpty ? nil : trimmedNote
    }

    private func applyMove(_ item: Item, to list: ListKind, remindAt: Date?) {
        let from = item.list
        item.list = list
        item.movedToTomorrow = false
        switch list {
        case .now:
            item.reason = Reason.intoNow(from: from)
            item.reminder = nil
        case .later:
            item.reason = nil
            if let remindAt {
                item.reminder = .date(remindAt)
            } else if item.reminder == nil {
                item.reminder = .date(defaultLaterTime())
            }
        case .inbox, .someday:
            item.reason = nil
            item.reminder = nil
        }
    }

    private func recordUndo(restoring items: [Item]) {
        let snapshots = items.map { ($0, ItemSnapshot($0)) }
        undoAction = {
            for (item, snapshot) in snapshots { snapshot.apply(to: item) }
        }
    }

    private func fetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) -> [T] {
        do {
            return try context.fetch(descriptor)
        } catch {
            log.error("Fetch failed: \(error.localizedDescription)")
            return []
        }
    }

    private func save() {
        do {
            try context.save()
        } catch {
            log.error("Save failed: \(error.localizedDescription)")
        }
        onChange?()
    }
}

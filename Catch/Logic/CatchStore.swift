import Foundation
import OSLog
import SwiftData

/// All the rules for moving things between lists, enforcing the Now limit,
/// projects and the evening wrap-up. Views call this rather than editing models directly.
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
    private let log = Logger(subsystem: "com.jakefrenzel.catch", category: "store")

    init(context: ModelContext,
         settingsStore: SettingsStore,
         calendar: Calendar = .current,
         now: @escaping () -> Date = Date.init) {
        self.context = context
        self.settingsStore = settingsStore
        self.calendar = calendar
        self.now = now
    }

    var settings: CatchSettings { settingsStore.settings }

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

    var openNowItems: [Item] { allItems().filter(\.isOpenInNow) }

    var isNowFull: Bool { openNowItems.count >= settings.maxNow }

    func upFirstCandidates() -> [UpFirstCandidate] {
        UpFirst.candidates(items: allItems(), projects: projects(), includeSteps: settings.upFirstIncludesSteps)
    }

    /// When a Later item with no chosen time comes back: the next "After work" time.
    func defaultLaterTime() -> Date {
        settings.afterWork.next(after: now(), calendar: calendar)
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
        save()
        return .moved
    }

    /// Sends `outgoing` from Now back to Inbox and puts `incoming` in its place.
    func swap(incoming: Item, outgoing: Item) {
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
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { item.text = trimmed }
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        item.note = trimmedNote.isEmpty ? nil : trimmedNote
        save()
    }

    func setDone(_ item: Item, _ done: Bool) {
        item.completedAt = done ? now() : nil
        save()
    }

    func setDone(_ step: Step, _ done: Bool) {
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
        context.delete(item)
        save()
    }

    // MARK: - Evening wrap-up

    func moveToTomorrow(_ item: Item) {
        item.movedToTomorrow = true
        save()
    }

    /// "All to Tomorrow" / Finish. Returns how many items moved.
    @discardableResult
    func moveAllToTomorrow() -> Int {
        let open = openNowItems
        open.forEach { $0.movedToTomorrow = true }
        save()
        return open.count
    }

    /// Next morning: brings back everything moved to tomorrow.
    func carryOverFromLastNight() {
        for item in allItems() where item.movedToTomorrow {
            item.movedToTomorrow = false
            item.reason = Reason.carriedOver
        }
        save()
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

        for item in draft.inboxItems { context.delete(item) }
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
        save()
        return step
    }

    // MARK: - Private

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
    }
}

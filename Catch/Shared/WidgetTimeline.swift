import Foundation

/// What the home screen widget shows at a moment (12b–12d). Pure, so it can be
/// built from fetched items in the widget and tested in the app.
struct WidgetSnapshot: Equatable {
    enum Mode: Equatable {
        /// 12b: the Up first suggestion, with Done and Skip.
        case upFirst(itemID: UUID?, stepID: UUID?, title: String, reason: String)
        /// 12c: a Later reminder that's due, with Done and In 1 Hour.
        case laterDue(itemID: UUID, title: String, time: String, detail: String)
        /// 12d: from the wrap-up time, what's left.
        case evening(left: Int, done: Int, time: String)
        /// Nothing to suggest.
        case clear(done: Int)
        /// The shared store couldn't be read, as before Catch has first run.
        case unavailable
    }

    var mode: Mode
    /// The medium size's list: the rest of Now, what's still in Now, or what's left.
    var listTitle: String
    var list: [String]
    var inboxCount: Int

    static let placeholder = WidgetSnapshot(
        mode: .upFirst(itemID: nil, stepID: nil, title: "Send Q3 invoice to Halden", reason: "In Now since Tue"),
        listTitle: "NOW · 2 OF 3", list: ["Call Dana about the lease", "Order cabinet samples"], inboxCount: 4)

    /// Shown in place of the user's day when it can't be read, so sample data never passes for theirs.
    static let unavailable = WidgetSnapshot(mode: .unavailable, listTitle: "", list: [], inboxCount: 0)
}

enum WidgetTimeline {
    static func snapshot(at date: Date, items: [Item], projects: [Project], settings: CatchSettings,
                         skipped: Set<UUID>, calendar: Calendar, formatter: ReminderFormatter) -> WidgetSnapshot {
        // Items moved to tomorrow count again once tomorrow arrives, even before
        // the app has run and brought them back.
        // Returning items only fill the room left in Now, as carry-over will.
        let staying = items.filter { $0.list == .now && !$0.isDone && !$0.movedToTomorrow }
        let returning = items
            .filter { $0.list == .now && !$0.isDone && WrapUp.isBackFromTomorrow($0, at: date, calendar: calendar) }
            .sorted { $0.capturedAt < $1.capturedAt }
        let room = max(0, settings.maxNow - staying.count)
        let open = (staying + returning.prefix(room)).sorted { $0.capturedAt < $1.capturedAt }
        let doneToday = items.filter { item in
            guard let completedAt = item.completedAt else { return false }
            return (item.list == .now || item.list == .later) && DayClock.isSameDay(completedAt, date, calendar: calendar)
        }.count
        let inboxCount = items.filter { $0.list == .inbox }.count

        if WrapUp.isEvening(now: date, settings: settings, calendar: calendar) {
            let wrapUp = calendar.date(bySettingHour: settings.wrapUpTime.hour, minute: settings.wrapUpTime.minute,
                                       second: 0, of: date) ?? date
            return WidgetSnapshot(mode: .evening(left: open.count, done: doneToday,
                                                 time: formatter.timeLabel(wrapUp)),
                                  listTitle: "LEFT", list: Array(open.prefix(3).map(\.text)), inboxCount: inboxCount)
        }

        // The most recently due Later reminder from today takes the top spot.
        let due = items
            .filter { $0.list == .later && !$0.isDone }
            .compactMap { item -> (Item, Date)? in
                guard let remindAt = item.remindAt, remindAt <= date,
                      calendar.isDate(remindAt, inSameDayAs: date) else { return nil }
                return (item, remindAt)
            }
            .max { $0.1 < $1.1 }
        if let due {
            let (item, remindAt) = due
            return WidgetSnapshot(mode: .laterDue(itemID: item.id, title: item.text,
                                                  time: formatter.timeLabel(remindAt),
                                                  detail: item.note ?? "From your Later list"),
                                  listTitle: "STILL IN NOW", list: Array(open.prefix(2).map(\.text)),
                                  inboxCount: inboxCount)
        }

        // UpFirst skips anything flagged as moved to tomorrow, so offer the open list's projects' steps
        // alongside items still flagged but already back.
        var candidates = open.map(UpFirstCandidate.item)
        if settings.upFirstIncludesSteps {
            candidates += UpFirst.candidates(items: [], projects: projects, includeSteps: true)
        }
        if let first = UpFirst(skipped: skipped).current(in: candidates) {
            let mode: WidgetSnapshot.Mode
            switch first {
            case .item(let item):
                mode = .upFirst(itemID: item.id, stepID: nil, title: item.text, reason: first.reason)
            case .step(let step, _):
                mode = .upFirst(itemID: nil, stepID: step.id, title: step.text, reason: first.reason)
            }
            let rest = open.filter { $0.id != first.key }
            return WidgetSnapshot(mode: mode, listTitle: "NOW · \(open.count) OF \(settings.maxNow)",
                                  list: Array(rest.prefix(2).map(\.text)), inboxCount: inboxCount)
        }

        return WidgetSnapshot(mode: .clear(done: doneToday), listTitle: "", list: [], inboxCount: inboxCount)
    }

    /// When the widget should change: now, each Later reminder still to come
    /// today, the wrap-up time, and when the day turns over at 4 AM.
    static func entryDates(now: Date, items: [Item], settings: CatchSettings, calendar: Calendar) -> [Date] {
        var dates: Set<Date> = [now]
        let nextDay = DayClock.nextStart(after: now, calendar: calendar)
        for item in items where item.list == .later && !item.isDone {
            if let remindAt = item.remindAt, remindAt > now, remindAt < nextDay {
                dates.insert(remindAt)
            }
        }
        if settings.wrapUpStyle == .onToday {
            let wrapUp = settings.wrapUpTime.next(after: now, calendar: calendar)
            if wrapUp < nextDay { dates.insert(wrapUp) }
        }
        dates.insert(nextDay)
        return dates.sorted()
    }
}

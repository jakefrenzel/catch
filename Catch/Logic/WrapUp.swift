import Foundation

/// Catch's day runs from 4 AM to 4 AM, so a wrap-up at 12:30 AM still belongs
/// to the evening before, and things moved to tomorrow come back that morning.
enum DayClock {
    static let startHour = 4

    /// The start of the Catch day `date` falls in. Reads the wall clock, so
    /// daylight-saving changes don't move the 4 AM boundary.
    static func day(of date: Date, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: date)
        guard calendar.component(.hour, from: date) < startHour else { return start }
        return calendar.date(byAdding: .day, value: -1, to: start) ?? start
    }

    /// When the next Catch day begins (the coming 4 AM).
    static func nextStart(after date: Date, calendar: Calendar) -> Date {
        let next = calendar.date(byAdding: .day, value: 1, to: day(of: date, calendar: calendar)) ?? date
        return calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: next) ?? next
    }

    /// Midnight starting tomorrow, by the Catch day: at 1 AM Sunday, still Saturday night,
    /// tomorrow is Sunday.
    static func tomorrow(after date: Date, calendar: Calendar) -> Date {
        let today = day(of: date, calendar: calendar)
        return calendar.date(byAdding: .day, value: 1, to: today) ?? today
    }

    static func isSameDay(_ a: Date, _ b: Date, calendar: Calendar) -> Bool {
        day(of: a, calendar: calendar) == day(of: b, calendar: calendar)
    }

    /// Minutes since the Catch day started (0 at 4 AM).
    static func minutesIntoDay(hour: Int, minute: Int) -> Int {
        (hour * 60 + minute - startHour * 60 + 24 * 60) % (24 * 60)
    }
}

/// 7a: the evening wrap-up on Today.
enum WrapUp {
    /// From the wrap-up time until the day turns over at 4 AM, when the style is On Today.
    static func isEvening(now: Date, settings: CatchSettings, calendar: Calendar) -> Bool {
        guard settings.wrapUpStyle == .onToday else { return false }
        guard isEveningTime(settings.wrapUpTime) else { return false }
        let parts = calendar.dateComponents([.hour, .minute], from: now)
        let minutes = DayClock.minutesIntoDay(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
        return minutes >= DayClock.minutesIntoDay(hour: settings.wrapUpTime.hour, minute: settings.wrapUpTime.minute)
    }

    /// Noon until 4 AM. A wrap-up time between 4 AM and noon isn't an evening, so neither
    /// Today nor the alert uses it, rather than turn the whole day into one.
    static func isEveningTime(_ time: TimeOfDay) -> Bool {
        DayClock.minutesIntoDay(hour: time.hour, minute: time.minute) >= 8 * 60
    }

    /// Moved to tomorrow, and tomorrow has come (even if the app hasn't run yet).
    static func isBackFromTomorrow(_ item: Item, at date: Date, calendar: Calendar) -> Bool {
        guard item.movedToTomorrow else { return false }
        let movedDay = DayClock.day(of: item.movedToTomorrowAt ?? .distantPast, calendar: calendar)
        return movedDay < DayClock.day(of: date, calendar: calendar)
    }

    /// What the evening card says.
    struct Card: Equatable {
        let title: String
        let subtitle: String
        let canFinish: Bool
    }

    static func card(left: Int, movedToTomorrow: Int, isFinished: Bool) -> Card {
        if left > 0 {
            return Card(title: "\(left) left for today", subtitle: "Move them on, then finish the day", canFinish: true)
        }
        if isFinished {
            return Card(title: "Day finished", subtitle: "Good night. Up first is ready in the morning.", canFinish: false)
        }
        return Card(title: "Nothing left for today",
                    subtitle: movedToTomorrow > 0 ? "\(movedToTomorrow) moved to tomorrow" : "Finish when you’re ready",
                    canFinish: true)
    }

    /// Whether a list row belongs on today's Today: open, or done today.
    /// Keeps finished items from piling up in Now and Later day after day.
    static func isVisibleToday(_ item: Item, now: Date, calendar: Calendar) -> Bool {
        guard let completedAt = item.completedAt else { return true }
        return DayClock.isSameDay(completedAt, now, calendar: calendar)
    }
}

// MARK: - What got done

extension WrapUp {
    /// One thing checked off today, for the wrap-up's done card.
    struct Done: Identifiable {
        enum Kind {
            case now
            case later
            /// A project step, with its project's name.
            case step(project: String)
        }

        let id: UUID
        let title: String
        let kind: Kind
        let completedAt: Date
        /// The Later item, so its reminder time can show.
        let item: Item?
        let step: Step?
    }

    /// The project a step was checked off in today that's closest to done.
    struct Closer: Equatable {
        let projectID: UUID
        let name: String
        let progress: Double
        let left: Int

        /// "2 steps to go", or "Finished" once the last one is done.
        var label: String {
            switch left {
            case 0: return "Finished"
            case 1: return "1 step to go"
            default: return "\(left) steps to go"
            }
        }
    }

    struct Summary {
        /// Oldest first, the order they were done in.
        let done: [Done]
        let closer: Closer?

        var count: Int { done.count }
        var isEmpty: Bool { done.isEmpty }

        /// "4 done today"
        var title: String { "\(count) done today" }

        /// Calls out project steps, the progress that's easiest to miss: "Including a step on Kitchen reno".
        var stepsLine: String? {
            var projects: [String] = []
            var steps = 0
            for entry in done {
                guard case .step(let project) = entry.kind else { continue }
                steps += 1
                if !projects.contains(project) { projects.append(project) }
            }
            switch (steps, projects.count) {
            case (0, _): return nil
            case (1, _): return "Including a step on \(projects[0])"
            case (_, 1): return "Including \(steps) steps on \(projects[0])"
            default: return "Including steps on \(projects.count) projects"
            }
        }

        /// After Finish: "4 done today. 2 moved to tomorrow."
        func finishedLine(movedToTomorrow: Int) -> String {
            movedToTomorrow > 0 ? "\(title). \(movedToTomorrow) moved to tomorrow." : "\(title)."
        }
    }

    /// Everything in Now, Later and projects checked off during the Catch day `now` falls in.
    /// Never says what wasn't done: an empty summary shows nothing.
    static func summary(items: [Item], projects: [Project], now: Date, calendar: Calendar) -> Summary {
        func today(_ date: Date?) -> Bool {
            guard let date else { return false }
            return DayClock.isSameDay(date, now, calendar: calendar)
        }

        var done: [Done] = items.compactMap { item in
            guard today(item.completedAt), let completedAt = item.completedAt else { return nil }
            switch item.list {
            case .now:
                return Done(id: item.id, title: item.text, kind: .now, completedAt: completedAt, item: item, step: nil)
            case .later:
                return Done(id: item.id, title: item.text, kind: .later, completedAt: completedAt, item: item, step: nil)
            case .inbox, .someday:
                return nil
            }
        }

        var closer: Closer?
        for project in projects {
            let stepsToday = project.orderedSteps.filter { today($0.completedAt) }
            guard !stepsToday.isEmpty else { continue }
            for step in stepsToday {
                done.append(Done(id: step.id, title: step.text, kind: .step(project: project.name),
                                 completedAt: step.completedAt ?? now, item: nil, step: step))
            }
            let left = project.orderedSteps.count - project.doneCount
            if closer == nil || left < closer!.left {
                closer = Closer(projectID: project.id, name: project.name, progress: project.progress, left: left)
            }
        }

        done.sort { $0.completedAt < $1.completedAt }
        return Summary(done: done, closer: closer)
    }
}

import Foundation

/// 7a: the evening wrap-up on Today.
enum WrapUp {
    /// From the wrap-up time until midnight, when the style is On Today.
    static func isEvening(now: Date, settings: CatchSettings, calendar: Calendar) -> Bool {
        guard settings.wrapUpStyle == .onToday else { return false }
        let parts = calendar.dateComponents([.hour, .minute], from: now)
        let minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        return minutes >= settings.wrapUpTime.hour * 60 + settings.wrapUpTime.minute
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
        return calendar.isDate(completedAt, inSameDayAs: now)
    }
}

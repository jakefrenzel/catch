import Foundation

/// The short time label on a Later row: "5:30 PM", "Mon 9 AM", "Oct 20 9 AM", "Leaving Office".
struct ReminderFormatter {
    var calendar: Calendar = .current
    var locale: Locale = .current

    func label(for reminder: ReminderTime, now: Date) -> String {
        switch reminder {
        case .place(.leave, let place):
            return "Leaving \(place.name)"
        case .place(.arrive, let place):
            return "Arriving \(place.name)"
        case .date(let date):
            return label(for: date, now: now)
        }
    }

    func label(for date: Date, now: Date) -> String {
        let time = timeLabel(date)
        if calendar.isDate(date, inSameDayAs: now) { return time }

        let startOfToday = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: startOfToday, to: calendar.startOfDay(for: date)).day ?? 0
        if (1...6).contains(days) {
            return "\(format(date, .dateTime.weekday(.abbreviated))) \(time)"
        }
        return "\(format(date, .dateTime.month(.abbreviated).day())) \(time)"
    }

    /// "9 AM" on the hour, "5:30 PM" otherwise.
    private func timeLabel(_ date: Date) -> String {
        let minute = calendar.component(.minute, from: date)
        return minute == 0 ? format(date, .dateTime.hour()) : format(date, .dateTime.hour().minute())
    }

    private func format(_ date: Date, _ style: Date.FormatStyle) -> String {
        var style = style
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        style.locale = locale
        return date.formatted(style)
    }
}

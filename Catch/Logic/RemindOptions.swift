import Foundation

/// A suggestion on the Remind sheet (6g).
struct RemindOption: Identifiable, Equatable {
    enum Kind: Hashable {
        case afternoon, afterWork, tonight, tomorrowMorning
        case leave(UUID)
    }

    let kind: Kind
    let title: String
    let reminder: ReminderTime

    var id: Kind { kind }

    var date: Date? {
        if case .date(let date) = reminder { return date }
        return nil
    }
}

enum RemindOptions {
    /// The suggestions, in the prototype's order. "This afternoon" and "Tonight"
    /// only appear while they're still ahead; "After work" is always the next one.
    static func options(now: Date, calendar: Calendar, afterWork: TimeOfDay, places: [Place]) -> [RemindOption] {
        var result: [RemindOption] = []

        func today(_ hour: Int) -> Date? {
            guard let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now), date > now else {
                return nil
            }
            return date
        }

        if let afternoon = today(15) {
            result.append(RemindOption(kind: .afternoon, title: "This afternoon", reminder: .date(afternoon)))
        }
        result.append(RemindOption(kind: .afterWork, title: "After work",
                                   reminder: .date(afterWork.next(after: now, calendar: calendar))))
        if let tonight = today(20) {
            result.append(RemindOption(kind: .tonight, title: "Tonight", reminder: .date(tonight)))
        }
        for place in places {
            result.append(RemindOption(kind: .leave(place.id), title: "When I leave \(place.name)",
                                       reminder: .place(.leave, place)))
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)),
           let morning = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) {
            result.append(RemindOption(kind: .tomorrowMorning, title: "Tomorrow morning", reminder: .date(morning)))
        }
        return result
    }

    /// The seven days offered in the date picker's day strip, starting today.
    static func pickerDays(now: Date, calendar: Calendar) -> [Date] {
        let start = calendar.startOfDay(for: now)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    /// Combines a day from the strip with a time from the wheels.
    static func combine(day: Date, time: Date, calendar: Calendar) -> Date {
        let parts = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.date(bySettingHour: parts.hour ?? 9, minute: parts.minute ?? 0, second: 0, of: day) ?? day
    }

    /// Rounds up to the next quarter hour, to match the 15-minute wheel.
    static func roundedToQuarterHour(_ date: Date, calendar: Calendar) -> Date {
        let minute = calendar.component(.minute, from: date)
        let second = calendar.component(.second, from: date)
        guard minute % 15 != 0 || second != 0 else { return date }
        let add = (15 - minute % 15) * 60 - second
        return date.addingTimeInterval(TimeInterval(add))
    }
}

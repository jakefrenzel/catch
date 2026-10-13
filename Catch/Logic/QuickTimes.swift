import Foundation

/// A one-tap reminder time offered when capturing to Later.
struct QuickTime: Identifiable, Equatable {
    enum Kind: String {
        case tonight, tomorrow, weekend
    }

    let kind: Kind
    let date: Date

    var id: Kind { kind }

    var title: String {
        switch kind {
        case .tonight: return "Tonight"
        case .tomorrow: return "Tomorrow"
        case .weekend: return "This weekend"
        }
    }
}

enum QuickTimes {
    /// Tonight at 7 PM (only while it's still ahead), tomorrow at 9 AM,
    /// and the next Saturday at 10 AM.
    static func options(now: Date, calendar: Calendar) -> [QuickTime] {
        var result: [QuickTime] = []

        if let tonight = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: now), tonight > now {
            result.append(QuickTime(kind: .tonight, date: tonight))
        }

        let tomorrow = DayClock.tomorrow(after: now, calendar: calendar)
        if let morning = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) {
            result.append(QuickTime(kind: .tomorrow, date: morning))
        }

        let saturdayMorning = DateComponents(hour: 10, minute: 0, second: 0, weekday: 7)
        if let weekend = calendar.nextDate(after: now, matching: saturdayMorning, matchingPolicy: .nextTime) {
            result.append(QuickTime(kind: .weekend, date: weekend))
        }

        return result
    }
}

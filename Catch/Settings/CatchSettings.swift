import Foundation

/// A wall-clock time such as "After work" (5:30 PM) or the wrap-up time.
struct TimeOfDay: Codable, Hashable {
    var hour: Int
    var minute: Int

    /// The next time this time of day occurs strictly after `date`.
    func next(after date: Date, calendar: Calendar) -> Date {
        let match = DateComponents(hour: hour, minute: minute, second: 0)
        return calendar.nextDate(after: date, matching: match, matchingPolicy: .nextTime) ?? date
    }
}

struct CatchSettings: Codable, Equatable {
    enum WrapUpStyle: String, Codable, CaseIterable { case onToday, off }
    enum Appearance: String, Codable, CaseIterable { case system, light, dark }

    static let maxNowRange = 1...5

    // Reminders
    var notifications = true
    var nudgeDefault = true
    var afterWork = TimeOfDay(hour: 17, minute: 30)

    // Evening wrap-up
    var wrapUpTime = TimeOfDay(hour: 21, minute: 0)
    var wrapUpStyle = WrapUpStyle.onToday

    // Today
    var maxNow = 3 {
        didSet { maxNow = Self.clampMaxNow(maxNow) }
    }
    var upFirstIncludesSteps = true

    // Display
    var appearance = Appearance.system
    var haptics = true

    // Places
    var suggestPlaces = true
    var offerLeave = true
    var offerArrive = true

    // Capture. nil follows the system language.
    var voiceLanguage: String?

    static func clampMaxNow(_ value: Int) -> Int {
        min(max(value, maxNowRange.lowerBound), maxNowRange.upperBound)
    }

    enum CodingKeys: String, CodingKey {
        case notifications, nudgeDefault, afterWork, wrapUpTime, wrapUpStyle, maxNow,
             upFirstIncludesSteps, appearance, haptics, suggestPlaces, offerLeave, offerArrive, voiceLanguage
    }
}

extension CatchSettings {
    /// Missing or unreadable keys fall back to their defaults, so adding a setting
    /// in a later version doesn't reset everything else.
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? c.decodeIfPresent(T.self, forKey: key)) ?? fallback
        }
        notifications = value(.notifications, notifications)
        nudgeDefault = value(.nudgeDefault, nudgeDefault)
        afterWork = value(.afterWork, afterWork)
        wrapUpTime = value(.wrapUpTime, wrapUpTime)
        wrapUpStyle = value(.wrapUpStyle, wrapUpStyle)
        maxNow = Self.clampMaxNow(value(.maxNow, maxNow))
        upFirstIncludesSteps = value(.upFirstIncludesSteps, upFirstIncludesSteps)
        appearance = value(.appearance, appearance)
        haptics = value(.haptics, haptics)
        suggestPlaces = value(.suggestPlaces, suggestPlaces)
        offerLeave = value(.offerLeave, offerLeave)
        offerArrive = value(.offerArrive, offerArrive)
        voiceLanguage = try? c.decodeIfPresent(String.self, forKey: .voiceLanguage)
    }
}

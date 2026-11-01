import Foundation

/// What the app and the widget extension share through the App Group.
///
/// SwiftData's default configuration already puts the database in the App
/// Group container when the entitlement is present, so both processes open the
/// same file with a plain `ModelContainer(for:)`. Without the entitlement (an
/// unsigned CI build) each falls back to its own storage.
enum SharedStore {
    static let appGroup = "group.com.buildmonkeys.catch"

    /// Settings and small bits of state both processes read.
    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    /// Up first suggestions skipped from the widget, so the widget can move on.
    static let widgetSkippedKey = "widgetSkippedUpFirst"
    /// The Catch day the skips were made on; they're forgotten when it ends.
    static let widgetSkippedDayKey = "widgetSkippedUpFirstDay"

    /// What was skipped from the widget during the Catch day `date` falls in.
    /// Skips from an earlier day (or from before skips were dated) don't count.
    static func widgetSkipped(at date: Date = .now, calendar: Calendar = .current) -> Set<UUID> {
        widgetSkipped(in: defaults, at: date, calendar: calendar)
    }

    static func setWidgetSkipped(_ skipped: Set<UUID>, at date: Date = .now, calendar: Calendar = .current) {
        setWidgetSkipped(skipped, in: defaults, at: date, calendar: calendar)
    }

    static func widgetSkipped(in defaults: UserDefaults, at date: Date, calendar: Calendar) -> Set<UUID> {
        guard let stamp = defaults.object(forKey: widgetSkippedDayKey) as? Date,
              DayClock.isSameDay(stamp, date, calendar: calendar) else { return [] }
        let strings = defaults.stringArray(forKey: widgetSkippedKey) ?? []
        return Set(strings.compactMap(UUID.init(uuidString:)))
    }

    static func setWidgetSkipped(_ skipped: Set<UUID>, in defaults: UserDefaults, at date: Date, calendar: Calendar) {
        defaults.set(skipped.map(\.uuidString), forKey: widgetSkippedKey)
        defaults.set(date, forKey: widgetSkippedDayKey)
    }
}

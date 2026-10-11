import Foundation
import Observation

/// Holds the user's settings and writes every change to UserDefaults.
@Observable
final class SettingsStore {
    var settings: CatchSettings {
        didSet { save() }
    }

    /// When the user tapped Finish in the evening wrap-up.
    var dayFinishedOn: Date? {
        didSet { defaults.set(dayFinishedOn, forKey: Self.dayFinishedKey) }
    }

    /// The last day the app was open (start of day), to notice a new day.
    var lastActiveDay: Date? {
        didSet { defaults.set(lastActiveDay, forKey: Self.lastActiveDayKey) }
    }

    /// First launch has been finished or skipped.
    var hasOnboarded: Bool {
        didSet { defaults.set(hasOnboarded, forKey: Self.onboardedKey) }
    }

    private let defaults: UserDefaults
    private static let key = "settings.v1"
    private static let onboardedKey = "hasOnboarded"
    private static let dayFinishedKey = "dayFinishedOn"
    private static let lastActiveDayKey = "lastActiveDay"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(CatchSettings.self, from: data) {
            settings = saved
        } else {
            settings = CatchSettings()
        }
        dayFinishedOn = defaults.object(forKey: Self.dayFinishedKey) as? Date
        lastActiveDay = defaults.object(forKey: Self.lastActiveDayKey) as? Date
        hasOnboarded = defaults.bool(forKey: Self.onboardedKey)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.key)
    }
}

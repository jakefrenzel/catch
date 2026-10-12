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

    /// The Up first suggestion whose pinned bar was swiped away. It stays
    /// hidden, across launches, until something else is up first.
    var hiddenPinnedUpFirst: UUID? {
        didSet { defaults.set(hiddenPinnedUpFirst?.uuidString, forKey: Self.hiddenPinnedUpFirstKey) }
    }

    private let defaults: UserDefaults
    private static let key = "settings.v1"
    private static let onboardedKey = "hasOnboarded"
    private static let dayFinishedKey = "dayFinishedOn"
    private static let lastActiveDayKey = "lastActiveDay"
    private static let hiddenPinnedUpFirstKey = "hiddenPinnedUpFirst"

    /// `legacy` is where settings lived before they moved to the shared App Group;
    /// they're copied over once.
    init(defaults: UserDefaults = .standard, migratingFrom legacy: UserDefaults? = nil) {
        if let legacy, legacy !== defaults, defaults.data(forKey: Self.key) == nil,
           legacy.data(forKey: Self.key) != nil {
            for key in [Self.key, Self.dayFinishedKey, Self.onboardedKey] {
                if let value = legacy.object(forKey: key) { defaults.set(value, forKey: key) }
            }
        }
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
        hiddenPinnedUpFirst = defaults.string(forKey: Self.hiddenPinnedUpFirstKey).flatMap { UUID(uuidString: $0) }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.key)
    }
}

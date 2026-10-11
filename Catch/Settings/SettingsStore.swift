import Foundation
import Observation

/// Holds the user's settings and writes every change to UserDefaults.
@Observable
final class SettingsStore {
    var settings: CatchSettings {
        didSet { save() }
    }

    private let defaults: UserDefaults
    private static let key = "settings.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(CatchSettings.self, from: data) {
            settings = saved
        } else {
            settings = CatchSettings()
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.key)
    }
}

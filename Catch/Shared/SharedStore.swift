import Foundation

/// What the app and the widget extension share through the App Group.
///
/// SwiftData's default configuration already puts the database in the App
/// Group container when the entitlement is present, so both processes open the
/// same file with a plain `ModelContainer(for:)`. Without the entitlement (an
/// unsigned CI build) each falls back to its own storage.
enum SharedStore {
    static let appGroup = "group.com.jakefrenzel.catch"

    /// Settings and small bits of state both processes read.
    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    /// Up first suggestions skipped from the widget, so the widget can move on.
    static let widgetSkippedKey = "widgetSkippedUpFirst"

    static var widgetSkipped: Set<UUID> {
        get {
            let strings = defaults.stringArray(forKey: widgetSkippedKey) ?? []
            return Set(strings.compactMap(UUID.init(uuidString:)))
        }
        set {
            defaults.set(newValue.map(\.uuidString), forKey: widgetSkippedKey)
        }
    }
}

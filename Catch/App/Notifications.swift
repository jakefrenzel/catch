import CoreLocation
import Foundation
import UIKit
import UserNotifications

enum NotificationPermission {
    case notDetermined, denied, allowed
}

/// The notification center, behind a protocol so tests can use a fake.
@MainActor
protocol NotificationScheduling: AnyObject {
    func permission() async -> NotificationPermission
    /// Shows the system prompt. Returns whether notifications are allowed.
    func requestAuthorization() async -> Bool
    /// Replaces every pending Catch alert with these.
    func replacePending(with reminders: [PlannedReminder]) async
    /// Takes alerts already shown off the Notification Center unless their item is still open.
    func clearDelivered(keeping itemIDs: Set<UUID>) async
    /// Opens Catch's notification settings, for when the system won't ask again.
    func openSystemSettings()
    /// The item's place alert was set again, so it's armed again even if it already fired.
    func rearmPlace(for itemID: UUID)
}

enum NotificationAction {
    static let category = "LATER_ITEM"
    static let done = "DONE"
    static let snooze = "SNOOZE_1H"
    static let itemIDKey = "itemID"
}

@MainActor
final class SystemNotificationScheduler: NotificationScheduling {
    private let center = UNUserNotificationCenter.current()
    private let defaults: UserDefaults
    /// Place alerts handed to iOS: id → `PlaceArming.fingerprint`.
    private static let armedPlacesKey = "armedPlaceReminders"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private var armedPlaces: [String: String] {
        get { defaults.dictionary(forKey: Self.armedPlacesKey) as? [String: String] ?? [:] }
        set { defaults.set(newValue, forKey: Self.armedPlacesKey) }
    }

    func rearmPlace(for itemID: UUID) {
        armedPlaces = armedPlaces.filter { !$0.key.contains(itemID.uuidString) }
    }

    /// The Done and In 1 Hour buttons on reminder alerts.
    func registerCategories() {
        let done = UNNotificationAction(identifier: NotificationAction.done, title: "Done")
        let snooze = UNNotificationAction(identifier: NotificationAction.snooze, title: "In 1 Hour")
        center.setNotificationCategories([
            UNNotificationCategory(identifier: NotificationAction.category, actions: [done, snooze],
                                   intentIdentifiers: [], options: []),
        ])
    }

    func permission() async -> NotificationPermission {
        switch await center.notificationSettings().authorizationStatus {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        default: return .allowed
        }
    }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func replacePending(with reminders: [PlannedReminder]) async {
        // Adding a request replaces the pending one with the same id, so only the
        // unwanted ones go first: if iOS suspends Catch partway, the rest stay pending.
        let wanted = Set(reminders.map(\.id))
        let pending = await center.pendingNotificationRequests().map(\.identifier)
        let stale = pending.filter { !wanted.contains($0) }
        center.removePendingNotificationRequests(withIdentifiers: stale)
        let previouslyArmed = armedPlaces
        let fired = PlaceArming.fired(wanted: reminders, pendingIDs: Set(pending), armed: previouslyArmed)
        // Already fired place alerts stay recorded; ones no longer wanted are forgotten.
        var armed = previouslyArmed.filter { fired.contains($0.key) }
        defer { armedPlaces = armed }
        for reminder in reminders where !fired.contains(reminder.id) {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            if let itemID = reminder.itemID {
                content.categoryIdentifier = NotificationAction.category
                content.userInfo = [NotificationAction.itemIDKey: itemID.uuidString]
                content.threadIdentifier = itemID.uuidString
            } else {
                content.threadIdentifier = "wrapup"
            }

            let trigger: UNNotificationTrigger
            if let place = reminder.region {
                let region = CLCircularRegion(
                    center: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude),
                    radius: place.radius, identifier: reminder.id)
                region.notifyOnEntry = place.onArrive
                region.notifyOnExit = !place.onArrive
                trigger = UNLocationNotificationTrigger(region: region, repeats: false)
            } else {
                // The moment Catch shows, wherever the phone is then: a clock time
                // would fire hours off after crossing time zones.
                trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, reminder.fireDate.timeIntervalSinceNow),
                                                            repeats: false)
            }
            do {
                try await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
                if let region = reminder.region { armed[reminder.id] = PlaceArming.fingerprint(region) }
            } catch {
                // Not armed, so the next sync tries it again.
            }
        }
    }

    func clearDelivered(keeping itemIDs: Set<UUID>) async {
        let stale = await center.deliveredNotifications().filter { notification in
            let userInfo = notification.request.content.userInfo
            guard let itemID = (userInfo[NotificationAction.itemIDKey] as? String).flatMap(UUID.init(uuidString:))
            else { return false }
            return !itemIDs.contains(itemID)
        }
        center.removeDeliveredNotifications(withIdentifiers: stale.map(\.request.identifier))
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

/// Shows alerts while Catch is open and routes the Done / In 1 Hour buttons.
/// Uses the completion-handler callbacks and calls them on the main thread, as
/// iOS expects; the async versions can finish on a background thread.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    @MainActor weak var model: AppModel?

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        let itemID = (userInfo[NotificationAction.itemIDKey] as? String).flatMap(UUID.init(uuidString:))
        let action = response.actionIdentifier
        Task { @MainActor in
            if let itemID {
                await self.model?.handleNotificationAction(action, itemID: itemID)
            } else {
                // The wrap-up alert: open Today.
                self.model?.tab = .today
            }
            completionHandler()
        }
    }
}

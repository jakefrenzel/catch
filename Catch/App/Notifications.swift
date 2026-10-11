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
    /// Opens Catch's notification settings, for when the system won't ask again.
    func openSystemSettings()
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
        center.removeAllPendingNotificationRequests()
        for reminder in reminders {
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
                let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second],
                                                            from: reminder.fireDate)
                trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            }
            try? await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
        }
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

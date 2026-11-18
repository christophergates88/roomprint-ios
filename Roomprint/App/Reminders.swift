import Foundation
import UserNotifications

/// A gentle local reminder every six months to add what's new. Nothing leaves the phone.
enum Reminders {
    private static let id = "rp.update-reminder"

    /// Turns the reminder on or off. Returns whether it ended up on (off if the person declines notifications).
    static func set(_ on: Bool) async -> Bool {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard on else { return false }
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return false }
        let content = UNMutableNotificationContent()
        content.title = "Bought anything new?"
        content.body = "Take two minutes to add it to your home record, so it's covered if you ever need to claim."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 182 * 86400, repeats: true)
        do {
            try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            return true
        } catch {
            return false
        }
    }
}

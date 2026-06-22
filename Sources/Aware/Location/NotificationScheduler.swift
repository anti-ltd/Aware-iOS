import UserNotifications

/// Local notifications for the safety check-in timer. When a timer is running and
/// the deadline passes, iOS fires a notification prompting the user (and, by
/// extension, reminding them their contacts will expect an alert) even if Aware
/// is backgrounded or the phone is locked.
@MainActor
enum NotificationScheduler {
    private static let checkInID = "aware.checkin.deadline"

    /// Ask for alert/sound permission. Safe to call repeatedly.
    static func requestAuthorization() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Schedule the missed-check-in notification for `deadline`. Replaces any
    /// previously scheduled one.
    static func scheduleCheckIn(deadline: Date) {
        cancelCheckIn()
        let interval = deadline.timeIntervalSinceNow
        guard interval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Safety check-in missed"
        content.body = "Tap to confirm you're safe — or alert your trusted contacts."
        content.sound = .defaultCritical

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: checkInID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    static func cancelCheckIn() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [checkInID])
    }
}

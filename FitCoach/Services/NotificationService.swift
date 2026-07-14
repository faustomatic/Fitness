import Foundation
import UserNotifications

enum NotificationService {

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Weekly check-in reminder ("photo + weigh-in" prompt), repeating.
    static func scheduleCheckInReminder(weekday: Int, hour: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["weekly-checkin"])

        let content = UNMutableNotificationContent()
        content.title = "Weekly check-in 📸"
        content.body = "Time for your check-in: weigh in, grab your progress photos (front/side/back, same lighting) and log how the week felt. Takes 3 minutes."
        content.sound = .default

        var components = DateComponents()
        components.weekday = weekday
        components.hour = hour
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        center.add(UNNotificationRequest(identifier: "weekly-checkin", content: content, trigger: trigger))
    }

    /// A gentle nudge if a check-in is overdue by a day.
    static func scheduleOverdueNudge(weekday: Int, hour: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["checkin-nudge"])

        let content = UNMutableNotificationContent()
        content.title = "Still time to check in"
        content.body = "Yesterday's check-in is waiting. Consistency is what makes the trend data useful — jump in when you have a moment."
        content.sound = .default

        var components = DateComponents()
        components.weekday = weekday % 7 + 1
        components.hour = hour
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        center.add(UNNotificationRequest(identifier: "checkin-nudge", content: content, trigger: trigger))
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}

import Foundation
import UserNotifications

/// Local reminders for whoever currently has the room, so they don't have to babysit a
/// timer themselves. This is a lighter stand-in for a true Live Activity / lock screen
/// countdown: a real Live Activity needs a separate widget extension target, and pushing
/// a live update to the *other* roommate's phone needs real push notifications -- both
/// come with real added risk/cost right now (a new Xcode target, and Apple Push Notifications
/// require a paid Developer Program account, same wall as CloudKit). Local notifications
/// need neither, and still solve "don't make me watch the clock."
enum NotificationService {
    private static let warningID = "shorty.session.warning"
    private static let endID = "shorty.session.end"

    static func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Schedules a "5 minutes left" and a "time's up" reminder for a session ending at `end`.
    /// Safe to call repeatedly -- always clears any previously scheduled reminders first.
    static func scheduleSessionReminders(endingAt end: Date) {
        cancelSessionReminders()
        let center = UNUserNotificationCenter.current()
        let calendar = Calendar.current

        let warningTime = end.addingTimeInterval(-5 * 60)
        if warningTime > Date() {
            let content = UNMutableNotificationContent()
            content.title = "5 minutes left"
            content.body = "Your room time wraps up soon."
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: warningTime),
                repeats: false
            )
            center.add(UNNotificationRequest(identifier: warningID, content: content, trigger: trigger))
        }

        if end > Date() {
            let content = UNMutableNotificationContent()
            content.title = "Time's up"
            content.body = "Your room time has ended -- your roommate's up next."
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: end),
                repeats: false
            )
            center.add(UNNotificationRequest(identifier: endID, content: content, trigger: trigger))
        }
    }

    static func cancelSessionReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [warningID, endID])
    }
}

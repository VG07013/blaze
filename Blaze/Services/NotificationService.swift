import Foundation
import UserNotifications

/// All local notifications, written in Blaze's warm, slightly needy voice.
/// Everything is rescheduled from scratch whenever state changes, so the
/// pending queue always reflects reality and never spams.
final class NotificationService {
    static let shared = NotificationService()
    private let center = UNUserNotificationCenter.current()

    private enum ID {
        static let morning = "blaze.morning"
        static let middayToday = "blaze.midday.today"
        static let eveningToday = "blaze.evening.today"
        static let eveningTomorrow = "blaze.evening.tomorrow"
        static let lastChanceToday = "blaze.lastchance.today"
        static let lastChanceTomorrow = "blaze.lastchance.tomorrow"
        static let rollover = "blaze.rollover"
        static let comeback = "blaze.comeback"
        static let milestone = "blaze.milestone"
    }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func authorizationGranted() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
    }

    // MARK: - Master reschedule

    /// Rebuilds the entire pending queue from current state.
    func reschedule(settings: AppSettings, profile: UserProfile, questsDoneToday: Int) {
        center.removeAllPendingNotificationRequests()
        guard settings.notificationsEnabled else { return }

        let now = Date.now

        // Morning nudge — repeating daily at the user's chosen time.
        if settings.morningEnabled && !settings.isQuiet(minuteOfDay: settings.reminderMinutes) {
            var comps = DateComponents()
            comps.hour = settings.reminderMinutes / 60
            comps.minute = settings.reminderMinutes % 60
            add(id: ID.morning,
                title: "Blaze",
                body: "New day, new quests. Let's keep the fire going. 🔥",
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true))
        }

        // Midday check-in — today only, only while nothing's done.
        if settings.middayEnabled && questsDoneToday == 0 {
            scheduleAt(minuteOfDay: 13 * 60, on: now, after: now, settings: settings,
                       id: ID.middayToday,
                       title: "Blaze",
                       body: "Still quiet over here… one small quest keeps me bright. ✨")
        }

        // Evening warning — Blaze gets worried.
        if settings.eveningEnabled {
            if questsDoneToday == 0 {
                scheduleAt(minuteOfDay: 19 * 60, on: now, after: now, settings: settings,
                           id: ID.eveningToday,
                           title: "Blaze is worried",
                           body: "My flame's getting low… one quick quest and I'm good. 🥺")
            }
            // Arm tomorrow's too, in case the app isn't opened all day.
            if profile.streakCount > 0 || questsDoneToday > 0 {
                scheduleAt(minuteOfDay: 19 * 60, on: now.addingDays(1), after: now, settings: settings,
                           id: ID.eveningTomorrow,
                           title: "Blaze is worried",
                           body: "My flame's getting low… one quick quest and I'm good. 🥺")
            }
        }

        // Last-chance alert — only when the streak is truly at risk (no freeze to spend).
        if settings.lastChanceEnabled && profile.streakCount > 0 && profile.freezesHeld == 0 {
            if questsDoneToday == 0 {
                scheduleAt(minuteOfDay: 21 * 60, on: now, after: now, settings: settings,
                           id: ID.lastChanceToday,
                           title: "Streak at risk!",
                           body: "Streak's about to break. Save me before midnight! 🚨")
            }
            scheduleAt(minuteOfDay: 21 * 60, on: now.addingDays(1), after: now, settings: settings,
                       id: ID.lastChanceTomorrow,
                       title: "Streak at risk!",
                       body: "Streak's about to break. Save me before midnight! 🚨")
        }

        // Rollover alert — fires just past midnight if today ends with nothing done,
        // shifted to the end of quiet hours so it never wakes anyone.
        if questsDoneToday == 0 && profile.streakCount > 0 && settings.freezeAlertsEnabled {
            let tomorrow = now.addingDays(1)
            let fireMinute = settings.isQuiet(minuteOfDay: 5)
                ? settings.quietEndMinutes
                : 5
            let title: String
            let body: String
            if profile.freezesHeld > 0 {
                title = "Streak freeze used"
                body = "Used a streak freeze to keep us alive. Down to \(profile.freezesHeld - 1) left. 🧊"
            } else {
                title = "The fire went out"
                body = "My fire went out… but I can come back. Do one quest to bring me back to life."
            }
            scheduleAt(minuteOfDay: fireMinute, on: tomorrow, after: now, settings: settings,
                       id: ID.rollover, title: title, body: body, ignoreQuiet: true)
        }
    }

    // MARK: - One-off events

    /// Triumphant milestone note (7/30/100/365), sent moments after the hit.
    func sendMilestone(days: Int, settings: AppSettings) {
        guard settings.notificationsEnabled && settings.milestoneEnabled else { return }
        add(id: ID.milestone,
            title: "\(days)-day streak!",
            body: "\(days) day streak! I evolved. Come see the new me. ✨",
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false))
    }

    /// Gentle comeback nudge two days after a burnout.
    func scheduleComeback(settings: AppSettings) {
        guard settings.notificationsEnabled && settings.comebackEnabled else { return }
        add(id: ID.comeback,
            title: "Blaze",
            body: "The ashes are still warm. Ready to rise again?",
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 48 * 3600, repeats: false))
    }

    func cancelComeback() {
        center.removePendingNotificationRequests(withIdentifiers: [ID.comeback])
    }

    // MARK: - Helpers

    private func scheduleAt(minuteOfDay: Int, on day: Date, after: Date,
                            settings: AppSettings, id: String,
                            title: String, body: String, ignoreQuiet: Bool = false) {
        if !ignoreQuiet && settings.isQuiet(minuteOfDay: minuteOfDay) { return }
        guard let fireDate = Calendar.current.date(
            bySettingHour: minuteOfDay / 60,
            minute: minuteOfDay % 60,
            second: 0,
            of: day
        ), fireDate > after else { return }

        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: fireDate)
        add(id: id, title: title, body: body,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
    }

    private func add(id: String, title: String, body: String, trigger: UNNotificationTrigger) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }
}

/// Shows Blaze's notifications as banners even while the app is open.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Milestones already get a full-screen in-app celebration.
        notification.request.identifier == "blaze.milestone" ? [] : [.banner, .sound]
    }
}

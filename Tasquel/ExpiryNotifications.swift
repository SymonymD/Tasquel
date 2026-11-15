import UserNotifications

/// Expiration reminders as local notifications: the only file that imports
/// UserNotifications, so another platform can bring its own. Which reminders are due is
/// worked out by the store (`ChecklistStore.expiryReminders`); this keeps the pending
/// notifications the same as that list. Nothing leaves the device.
@MainActor
final class ExpiryNotifications: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ExpiryNotifications()

    private static let idPrefix = "expiry."
    /// The list last asked for, so an unchanged one isn't scheduled again.
    private var wanted: [ExpiryReminder]?
    /// Each update waits for the one before, so two can't mix their removals and adds.
    private var lastUpdate: Task<Void, Never>?
    private var center: UNUserNotificationCenter { .current() }

    /// So a reminder that comes while Tasquel is open still shows as a banner.
    func start() {
        center.delegate = self
    }

    /// Asks for permission the first time an expiration is set (never at launch), then
    /// schedules what's waiting.
    func requestPermissionIfNeeded() {
        guard !ChecklistStore.launchesWithThrowawayData else { return }
        Task {
            guard await center.notificationSettings().authorizationStatus == .notDetermined else { return }
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
            if let wanted { schedule(wanted) }
        }
    }

    /// Notifications are turned off for Tasquel in iOS Settings (Settings says so).
    func isDenied() async -> Bool {
        await center.notificationSettings().authorizationStatus == .denied
    }

    /// Schedules what's wanted again, for when permission may have changed in iOS Settings
    /// while Tasquel was away: `update` skips an unchanged list, so turning notifications on
    /// there left tasks already dated without reminders until the next change (the
    /// 2026-11-15 review).
    func recheck() {
        guard !ChecklistStore.launchesWithThrowawayData, let wanted else { return }
        schedule(wanted)
    }

    /// Makes the pending reminders exactly `reminders`.
    func update(_ reminders: [ExpiryReminder]) {
        guard !ChecklistStore.launchesWithThrowawayData, reminders != wanted else { return }
        wanted = reminders
        schedule(reminders)
    }

    private func schedule(_ reminders: [ExpiryReminder]) {
        let previous = lastUpdate
        lastUpdate = Task {
            await previous?.value
            let center = self.center
            let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(Self.idPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: pending)
            let status = await center.notificationSettings().authorizationStatus
            guard status == .authorized || status == .provisional || status == .ephemeral else { return }
            for reminder in reminders {
                try? await center.add(Self.request(for: reminder))
            }
        }
    }

    private static func request(for reminder: ExpiryReminder) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body
        content.sound = .default
        // On that day at 9 AM wherever the user is, by the Gregorian calendar the days are kept in.
        var components = DateComponents(year: reminder.day.year, month: reminder.day.month, day: reminder.day.day,
                                        hour: ExpiryReminder.hour)
        components.calendar = Calendar(identifier: .gregorian)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: idPrefix + reminder.id, content: content, trigger: trigger)
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}

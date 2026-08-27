import Foundation
import SwiftUI
import UserNotifications

extension Notification.Name {
    /// Posted when the user taps a PLOS notification; userInfo["category"] = "MORNING"/"EVENING".
    static let plosNotificationTap = Notification.Name("plosNotificationTap")
}

// MARK: - Local Notifications

@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationManager()

    /// Category of a notification tapped before the UI finished appearing (cold start).
    /// ContentView consumes this on appear; warm taps arrive via `.plosNotificationTap`.
    var pendingCategory: String?

    override private init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    /// Request permission and schedule default notifications.
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                print("Notification permission error: \(error)")
            }
            if granted {
                Task { @MainActor in
                    self.scheduleDefaults()
                }
            }
        }
    }

    /// Default: morning 8:00, evening 21:30 repeating daily.
    func scheduleDefaults() {
        // Remove previous
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        // Morning reminder
        var morningComp = DateComponents()
        morningComp.hour = 8
        morningComp.minute = 0
        let morningTrigger = UNCalendarNotificationTrigger(dateMatching: morningComp, repeats: true)
        let morningContent = UNMutableNotificationContent()
        morningContent.title = "生成今日计划"
        morningContent.body = "早上好！打开 PLOS 看看今天学什么。"
        morningContent.sound = .default
        morningContent.categoryIdentifier = "MORNING"
        let morningRequest = UNNotificationRequest(identifier: "morning-plan",
                                                    content: morningContent,
                                                    trigger: morningTrigger)
        UNUserNotificationCenter.current().add(morningRequest)

        // Evening reminder
        var eveningComp = DateComponents()
        eveningComp.hour = 21
        eveningComp.minute = 30
        let eveningTrigger = UNCalendarNotificationTrigger(dateMatching: eveningComp, repeats: true)
        let eveningContent = UNMutableNotificationContent()
        eveningContent.title = "一分钟汇报今天"
        eveningContent.body = "睡前花一分钟拖动滑块，明天系统接着今天重新排。"
        eveningContent.sound = .default
        eveningContent.categoryIdentifier = "EVENING"
        let eveningRequest = UNNotificationRequest(identifier: "evening-report",
                                                    content: eveningContent,
                                                    trigger: eveningTrigger)
        UNUserNotificationCenter.current().add(eveningRequest)
    }

    /// Update times when user changes them.
    func updateSchedule(morningHour: Int, morningMinute: Int,
                        eveningHour: Int, eveningMinute: Int,
                        morningEnabled: Bool, eveningEnabled: Bool) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        if morningEnabled {
            var comp = DateComponents()
            comp.hour = morningHour
            comp.minute = morningMinute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comp, repeats: true)
            let content = UNMutableNotificationContent()
            content.title = "生成今日计划"
            content.body = "早上好！打开 PLOS 看看今天学什么。"
            content.sound = .default
            content.categoryIdentifier = "MORNING"
            let request = UNNotificationRequest(identifier: "morning-plan",
                                                content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }

        if eveningEnabled {
            var comp = DateComponents()
            comp.hour = eveningHour
            comp.minute = eveningMinute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comp, repeats: true)
            let content = UNMutableNotificationContent()
            content.title = "一分钟汇报今天"
            content.body = "睡前花一分钟拖动滑块，明天系统接着今天重新排。"
            content.sound = .default
            content.categoryIdentifier = "EVENING"
            let request = UNNotificationRequest(identifier: "evening-report",
                                                content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                             didReceive response: UNNotificationResponse,
                                             withCompletionHandler completionHandler: @escaping () -> Void) {
        // P5 deep link: route by category. Stored for cold starts (UI not yet subscribed),
        // broadcast for warm taps.
        let category = response.notification.request.content.categoryIdentifier
        Task { @MainActor in
            NotificationManager.shared.pendingCategory = category
            NotificationCenter.default.post(name: .plosNotificationTap, object: nil,
                                            userInfo: ["category": category])
        }
        completionHandler()
    }
}

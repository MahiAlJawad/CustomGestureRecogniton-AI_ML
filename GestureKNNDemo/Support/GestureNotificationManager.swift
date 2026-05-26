import Foundation
import UserNotifications

enum GestureNotificationManager {
    static func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        guard settings.authorizationStatus == .notDetermined else { return }

        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            print("Failed to request notification authorization:", error)
        }
    }

    static func notifyDetectedGesture(_ label: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Gesture Detected"
        content.body = label
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "gesture-detected-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Failed to schedule gesture notification:", error)
        }
    }
}

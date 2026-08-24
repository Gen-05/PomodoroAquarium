import Foundation
import UserNotifications

protocol TimerNotificationScheduling {
    func requestAuthorizationIfNeeded()
    func scheduleStudyEnd(at date: Date)
    func scheduleBreakEnd(at date: Date)
    func cancelCurrentSessionNotification()
}

final class NotificationService: TimerNotificationScheduling, @unchecked Sendable {
    static let shared = NotificationService()
    static var appDefault: TimerNotificationScheduling {
        // XCTestホストではシステム許可UIを起動せず、注入したFakeで通知挙動を検証する。
        if NSClassFromString("XCTestCase") != nil ||
            ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return DisabledTimerNotificationService.shared
        }
        return shared
    }

    enum Identifier {
        static let studyEnd = "pomodoroAquarium.studyEnd"
        static let breakEnd = "pomodoroAquarium.breakEnd"

        static let sessionNotifications = [studyEnd, breakEnd]
    }

    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorizationIfNeeded() {
        withAuthorization { _ in }
    }

    func scheduleStudyEnd(at date: Date) {
        schedule(
            identifier: Identifier.studyEnd,
            title: "勉強終了！",
            body: "おつかれさまでした。報酬を確認しましょう。",
            at: date
        )
    }

    func scheduleBreakEnd(at date: Date) {
        schedule(
            identifier: Identifier.breakEnd,
            title: "休憩終了！",
            body: "次の勉強セットを始められます。",
            at: date
        )
    }

    func cancelCurrentSessionNotification() {
        center.removePendingNotificationRequests(withIdentifiers: Identifier.sessionNotifications)
        center.removeDeliveredNotifications(withIdentifiers: Identifier.sessionNotifications)
    }

    private func schedule(identifier: String, title: String, body: String, at date: Date) {
        cancelCurrentSessionNotification()
        guard date > Date() else { return }

        withAuthorization { [center] isAuthorized in
            guard isAuthorized else { return }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default

            let calendar = Calendar.current
            var components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: date
            )
            components.timeZone = calendar.timeZone
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            center.add(UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            ))
        }
    }

    private func withAuthorization(_ completion: @escaping @Sendable (Bool) -> Void) {
        center.getNotificationSettings { [center] settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                completion(true)
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    completion(granted)
                }
            case .denied:
                completion(false)
            @unknown default:
                completion(false)
            }
        }
    }
}

private final class DisabledTimerNotificationService: TimerNotificationScheduling {
    static let shared = DisabledTimerNotificationService()

    func requestAuthorizationIfNeeded() {}
    func scheduleStudyEnd(at date: Date) {}
    func scheduleBreakEnd(at date: Date) {}
    func cancelCurrentSessionNotification() {}
}

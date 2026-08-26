import Foundation
import UserNotifications

protocol TimerNotificationScheduling {
    var notificationsEnabled: Bool { get }
    func authorizationStatus(_ completion: @escaping @Sendable (NotificationAuthorizationState) -> Void)
    func requestAuthorization(_ completion: @escaping @Sendable (Bool) -> Void)
    func scheduleStudyEnd(at date: Date)
    func scheduleBreakEnd(at date: Date)
    func cancelCurrentSessionNotification()
}

enum NotificationSettings {
    static let enabledKey = "notificationsEnabled"

    static func isEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: enabledKey)
    }

    static func handleChange(
        isEnabled: Bool,
        notificationService: TimerNotificationScheduling = NotificationService.shared
    ) {
        guard !isEnabled else { return }
        notificationService.cancelCurrentSessionNotification()
    }
}

enum NotificationAuthorizationState: Equatable {
    case notDetermined
    case authorized
    case denied

    init(_ status: UNAuthorizationStatus) {
        switch status {
        case .authorized, .provisional, .ephemeral:
            self = .authorized
        case .denied:
            self = .denied
        case .notDetermined:
            self = .notDetermined
        @unknown default:
            self = .denied
        }
    }
}

enum NotificationIntroductionSettings {
    static let hasShownKey = "hasShownNotificationIntroduction"

    static func shouldPresent(for mode: TimerMode, hasShown: Bool) -> Bool {
        !hasShown && mode != .stopwatch
    }
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
    private let defaults: UserDefaults

    var notificationsEnabled: Bool {
        NotificationSettings.isEnabled(in: defaults)
    }

    init(
        center: UNUserNotificationCenter = .current(),
        defaults: UserDefaults = .standard
    ) {
        self.center = center
        self.defaults = defaults
    }

    func authorizationStatus(
        _ completion: @escaping @Sendable (NotificationAuthorizationState) -> Void
    ) {
        center.getNotificationSettings { settings in
            completion(NotificationAuthorizationState(settings.authorizationStatus))
        }
    }

    func requestAuthorization(_ completion: @escaping @Sendable (Bool) -> Void) {
        center.getNotificationSettings { [center] settings in
            switch NotificationAuthorizationState(settings.authorizationStatus) {
            case .authorized:
                completion(true)
            case .denied:
                completion(false)
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    completion(granted)
                }
            }
        }
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
        guard notificationsEnabled, date > Date() else { return }

        authorizationStatus { [center] status in
            guard case .authorized = status else { return }

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

}

private final class DisabledTimerNotificationService: TimerNotificationScheduling {
    static let shared = DisabledTimerNotificationService()

    var notificationsEnabled: Bool { false }

    func authorizationStatus(_ completion: @escaping @Sendable (NotificationAuthorizationState) -> Void) {
        completion(.denied)
    }
    func requestAuthorization(_ completion: @escaping @Sendable (Bool) -> Void) {
        completion(false)
    }
    func scheduleStudyEnd(at date: Date) {}
    func scheduleBreakEnd(at date: Date) {}
    func cancelCurrentSessionNotification() {}
}

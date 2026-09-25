import Foundation
import UserNotifications

protocol TimerNotificationScheduling {
    var notificationsEnabled: Bool { get }
    func authorizationStatus(_ completion: @escaping @Sendable (NotificationAuthorizationState) -> Void)
    func requestAuthorization(_ completion: @escaping @Sendable (Bool) -> Void)
    func scheduleStudyEnd(at date: Date)
    func scheduleBreakEnd(at date: Date)
    func scheduleBackgroundLimitNotifications(
        warningAt: Date?,
        failureAt: Date?,
        sessionIdentifier: String
    )
    func cancelCurrentSessionNotification()
    func cancelBackgroundLimitNotifications(for sessionIdentifier: String?)
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
        notificationService.cancelBackgroundLimitNotifications(for: nil)
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

final class NotificationService: NSObject, TimerNotificationScheduling,
    UNUserNotificationCenterDelegate, @unchecked Sendable {
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
        static let backgroundWarningPrefix = "pomodoroAquarium.backgroundWarning."
        static let backgroundFailurePrefix = "pomodoroAquarium.backgroundFailure."

        static let sessionNotifications = [studyEnd, breakEnd]

        static func backgroundWarning(sessionIdentifier: String) -> String {
            backgroundWarningPrefix + sessionIdentifier
        }

        static func backgroundFailure(sessionIdentifier: String) -> String {
            backgroundFailurePrefix + sessionIdentifier
        }

        static func backgroundLimitNotifications(sessionIdentifier: String) -> [String] {
            [
                backgroundWarning(sessionIdentifier: sessionIdentifier),
                backgroundFailure(sessionIdentifier: sessionIdentifier)
            ]
        }
    }

    private let center: UNUserNotificationCenter
    private let defaults: UserDefaults
    private var schedulableBackgroundSessionIdentifiers = Set<String>()

    var notificationsEnabled: Bool {
        NotificationSettings.isEnabled(in: defaults)
    }

    init(
        center: UNUserNotificationCenter = .current(),
        defaults: UserDefaults = .standard
    ) {
        self.center = center
        self.defaults = defaults
        super.init()
        center.delegate = self
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
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

    func scheduleBackgroundLimitNotifications(
        warningAt: Date?,
        failureAt: Date?,
        sessionIdentifier: String
    ) {
        let identifiers = Identifier.backgroundLimitNotifications(
            sessionIdentifier: sessionIdentifier
        )
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
        schedulableBackgroundSessionIdentifiers.remove(sessionIdentifier)
        guard notificationsEnabled, warningAt != nil || failureAt != nil else { return }
        schedulableBackgroundSessionIdentifiers.insert(sessionIdentifier)

        authorizationStatus { [weak self] status in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard case .authorized = status else {
                    self.schedulableBackgroundSessionIdentifiers.remove(sessionIdentifier)
                    return
                }
                guard self.schedulableBackgroundSessionIdentifiers.contains(sessionIdentifier) else {
                    return
                }
                if let warningAt {
                    self.addNotification(
                        identifier: Identifier.backgroundWarning(sessionIdentifier: sessionIdentifier),
                        title: "魚があなたを待っています",
                        body: "そろそろ水槽に戻りましょう。",
                        at: warningAt
                    )
                }
                if let failureAt {
                    self.addNotification(
                        identifier: Identifier.backgroundFailure(sessionIdentifier: sessionIdentifier),
                        title: "魚が逃げてしまいました",
                        body: "5分以上アプリを離れたため、今回の集中は終了になります。",
                        at: failureAt
                    )
                }
#if DEBUG
                if warningAt != nil { print("Background warning scheduled: +180s") }
                if failureAt != nil { print("Background failure scheduled: +300s") }
#endif
            }
        }
    }

    func cancelCurrentSessionNotification() {
        center.removePendingNotificationRequests(withIdentifiers: Identifier.sessionNotifications)
        center.removeDeliveredNotifications(withIdentifiers: Identifier.sessionNotifications)
    }

    func cancelBackgroundLimitNotifications(for sessionIdentifier: String?) {
        if let sessionIdentifier {
            schedulableBackgroundSessionIdentifiers.remove(sessionIdentifier)
            let identifiers = Identifier.backgroundLimitNotifications(
                sessionIdentifier: sessionIdentifier
            )
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
            center.removeDeliveredNotifications(withIdentifiers: identifiers)
            return
        }

        schedulableBackgroundSessionIdentifiers.removeAll()
        let warningPrefix = Identifier.backgroundWarningPrefix
        let failurePrefix = Identifier.backgroundFailurePrefix
        center.getPendingNotificationRequests { [center] requests in
            let identifiers = requests.map(\.identifier).filter {
                $0.hasPrefix(warningPrefix) || $0.hasPrefix(failurePrefix)
            }
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
        }
        center.getDeliveredNotifications { [center] notifications in
            let identifiers = notifications.map(\.request.identifier)
                .filter {
                    $0.hasPrefix(warningPrefix) || $0.hasPrefix(failurePrefix)
                }
            center.removeDeliveredNotifications(withIdentifiers: identifiers)
        }
    }

    private func schedule(identifier: String, title: String, body: String, at date: Date) {
        cancelCurrentSessionNotification()
        guard notificationsEnabled, date > Date() else { return }

        authorizationStatus { [weak self] status in
            guard case .authorized = status, let self else { return }
            self.addNotification(identifier: identifier, title: title, body: body, at: date)
        }
    }

    private func addNotification(identifier: String, title: String, body: String, at date: Date) {
        guard date > Date() else { return }

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

final class DisabledTimerNotificationService: TimerNotificationScheduling {
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
    func scheduleBackgroundLimitNotifications(
        warningAt: Date?,
        failureAt: Date?,
        sessionIdentifier: String
    ) {}
    func cancelCurrentSessionNotification() {}
    func cancelBackgroundLimitNotifications(for sessionIdentifier: String?) {}
}

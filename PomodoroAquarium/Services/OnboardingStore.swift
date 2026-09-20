import Foundation

struct OnboardingStore {
    static let storageKey = "hasCompletedOnboarding"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasCompletedOnboarding: Bool {
        defaults.bool(forKey: Self.storageKey)
    }

    func complete() {
        defaults.set(true, forKey: Self.storageKey)
    }
}

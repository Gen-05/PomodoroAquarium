import Foundation

struct AquariumThemeStore {
    static let storageKey = "selectedAquariumBackgroundTheme"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var selectedTheme: AquariumBackgroundTheme {
        Self.theme(from: defaults.string(forKey: Self.storageKey))
    }

    func save(_ theme: AquariumBackgroundTheme) {
        defaults.set(theme.rawValue, forKey: Self.storageKey)
    }

    static func theme(from rawValue: String?) -> AquariumBackgroundTheme {
        guard let rawValue,
              let theme = AquariumBackgroundTheme(rawValue: rawValue) else {
            return .aquarium
        }
        return theme
    }
}

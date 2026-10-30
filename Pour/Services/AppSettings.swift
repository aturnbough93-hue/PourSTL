import SwiftUI

enum AppAppearance: String, CaseIterable {
    case system
    case light
    case dark

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var displayName: String { rawValue.capitalized }
}

/// User preferences persisted to UserDefaults (appearance, measurement unit,
/// onboarding). Injected as an @Observable environment object.
@Observable
final class AppSettings {
    private let defaults: UserDefaults

    var appearance: AppAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    var unit: UnitPreference {
        didSet { defaults.set(unit.rawValue, forKey: Keys.unit) }
    }

    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.onboarding) }
    }

    /// Venue seam — the checked-in venue id when venue mode lands.
    var checkedInVenueID: String? {
        didSet { defaults.set(checkedInVenueID, forKey: Keys.venue) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.appearance = AppAppearance(rawValue: defaults.string(forKey: Keys.appearance) ?? "") ?? .system
        self.unit = UnitPreference(rawValue: defaults.string(forKey: Keys.unit) ?? "") ?? .oz
        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.onboarding)
        self.checkedInVenueID = defaults.string(forKey: Keys.venue)
    }

    private enum Keys {
        static let appearance = "pour.appearance"
        static let unit = "pour.unit"
        static let onboarding = "pour.onboardingDone"
        static let venue = "pour.checkedInVenueID"
    }
}

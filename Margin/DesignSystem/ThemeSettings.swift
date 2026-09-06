import SwiftUI

/// User-tunable interface settings, persisted to UserDefaults.
///
/// @Observable means any view that reads these (including indirectly through
/// Theme.accent) re-renders when they change — so switching the accent recolors
/// the whole app live.
@Observable
final class ThemeSettings {
    static let shared = ThemeSettings()

    enum Appearance: String, CaseIterable {
        case system, light, dark

        var label: String {
            switch self {
            case .system: return "System"
            case .light: return "Light"
            case .dark: return "Dark"
            }
        }

        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }

    var accent: NotebookColor {
        didSet { defaults.set(accent.rawValue, forKey: "settings.accent") }
    }
    var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: "settings.appearance") }
    }
    var showDueSoon: Bool {
        didSet { defaults.set(showDueSoon, forKey: "settings.showDueSoon") }
    }
    var showRecents: Bool {
        didSet { defaults.set(showRecents, forKey: "settings.showRecents") }
    }
    var showFavorites: Bool {
        didSet { defaults.set(showFavorites, forKey: "settings.showFavorites") }
    }
    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: "settings.hasCompletedOnboarding") }
    }
    /// Opt-in Liquid Glass material on the floating drawing chrome (iOS 26+ only).
    /// Off by default — the flat editorial look stays untouched until the user flips it.
    var liquidGlass: Bool {
        didSet { defaults.set(liquidGlass, forKey: "settings.liquidGlass") }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.accent = NotebookColor(rawValue: defaults.string(forKey: "settings.accent") ?? "") ?? .orange
        self.appearance = Appearance(rawValue: defaults.string(forKey: "settings.appearance") ?? "") ?? .system
        self.showDueSoon = defaults.object(forKey: "settings.showDueSoon") as? Bool ?? true
        self.showRecents = defaults.object(forKey: "settings.showRecents") as? Bool ?? true
        self.showFavorites = defaults.object(forKey: "settings.showFavorites") as? Bool ?? true
        self.hasCompletedOnboarding = defaults.object(forKey: "settings.hasCompletedOnboarding") as? Bool ?? false
        self.liquidGlass = defaults.object(forKey: "settings.liquidGlass") as? Bool ?? false
    }
}

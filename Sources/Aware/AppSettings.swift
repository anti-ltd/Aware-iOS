import SwiftUI

/// Persisted user preferences. Backed by `@AppStorage` so they survive launches
/// without any account or server — Aware is local-first.
@Observable
final class AppSettings {
    /// Whether the safety map weights routes by crime density, lighting, etc.
    var preferSaferRoutes: Bool {
        didSet { defaults.set(preferSaferRoutes, forKey: "preferSaferRoutes") }
    }
    /// Whether SOS escalates to "always" background location automatically.
    var sosUsesBackgroundLocation: Bool {
        didSet { defaults.set(sosUsesBackgroundLocation, forKey: "sosUsesBackgroundLocation") }
    }
    /// Whether the crime heatmap overlay is shown on the map by default.
    var showCrimeHeatmap: Bool {
        didSet { defaults.set(showCrimeHeatmap, forKey: "showCrimeHeatmap") }
    }
    /// Whether the user has seen the first-run intro.
    var hasOnboarded: Bool {
        didSet { defaults.set(hasOnboarded, forKey: "hasOnboarded") }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        preferSaferRoutes = defaults.object(forKey: "preferSaferRoutes") as? Bool ?? true
        sosUsesBackgroundLocation = defaults.object(forKey: "sosUsesBackgroundLocation") as? Bool ?? true
        showCrimeHeatmap = defaults.object(forKey: "showCrimeHeatmap") as? Bool ?? false
        hasOnboarded = defaults.object(forKey: "hasOnboarded") as? Bool ?? false
    }
}

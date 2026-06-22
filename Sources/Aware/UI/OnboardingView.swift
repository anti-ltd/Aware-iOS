import SwiftUI
import iUXiOS

/// Aware's first-run intro — content only. The paged flow, tinted backdrop and
/// permission-row chrome live in iUXiOS.OnboardingFlow so every app in the
/// family shares the same look.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings

    var body: some View {
        OnboardingFlow(pages: pages) {
            settings.hasOnboarded = true
        }
    }

    private var pages: [OnboardingPage] {
        [
            .init(symbol: "shield.lefthalf.filled", tint: .accentColor,
                  title: "Welcome to Aware",
                  message: "Your pocket safety app. Know what's around you, get help fast, and keep people you trust in the loop."),
            .init(symbol: "exclamationmark.triangle.fill", tint: .orange,
                  title: "Not an emergency service",
                  message: "Aware helps you stay aware and reach people you trust. It is not a life-saving device and may fail when you need it most. In a real emergency, call \(EmergencyServices.localNumber)."),
            .init(symbol: "map.fill", tint: .teal,
                  title: "See what's nearby",
                  message: "Police, hospitals, pharmacies, transport. Plus a crime heatmap built from official open data, not random posts."),
            .init(symbol: "point.topleft.down.to.point.bottomright.curvepath.fill", tint: .blue,
                  title: "Find a safer way",
                  message: "Press and hold anywhere on the map, or search a place. Aware finds a walking route that skips the rougher streets, not just the quickest one."),
            .init(symbol: "sos", tint: .red,
                  title: "Help in a tap",
                  message: "SOS, live location, and check-in timers. One tap shows your trusted contacts where you are. Always free."),
            .init(symbol: "lock.fill", tint: .green,
                  title: "Yours, kept private",
                  message: "You choose who sees your location, and when. Your medical info never leaves your phone. No account needed."),
            .init(symbol: "checkmark.shield.fill", tint: .accentColor,
                  title: "Just two things",
                  message: "Turn these on so Aware can actually help. You decide when your location gets shared.",
                  actions: [
                    .init(symbol: "location.fill", tint: .blue, title: "Location",
                          detail: "For nearby help, safer routes, and sharing") {
                        model.location.requestWhenInUse()
                    },
                    .init(symbol: "bell.fill", tint: .orange, title: "Notifications",
                          detail: "So a missed check-in can reach you") {
                        NotificationScheduler.requestAuthorization()
                    },
                  ]),
        ]
    }
}

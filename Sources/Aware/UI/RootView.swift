import SwiftUI
import iUXiOS

/// The app's top-level tabs. Held in `AppModel` so a screen (e.g. the Routes
/// search) can jump the user to another tab programmatically.
enum AppTab: Hashable {
    case map, routes, safety, contacts, profile
}

/// Tab shell. Map-first: the safety map is the home tab and the hub every other
/// feature hangs off, exactly as the product proposal frames it.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.selectedTab) {
            SafetyMapView()
                .tabItem { Label("Map", systemImage: "map.fill") }
                .tag(AppTab.map)

            RoutesView()
                .tabItem { Label("Routes", systemImage: "point.topleft.down.to.point.bottomright.curvepath.fill") }
                .tag(AppTab.routes)

            SafetyView()
                .tabItem { Label("Safety", systemImage: "shield.lefthalf.filled") }
                .tag(AppTab.safety)

            ContactsView()
                .tabItem { Label("Contacts", systemImage: "person.2.fill") }
                .tag(AppTab.contacts)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "cross.case.fill") }
                .tag(AppTab.profile)
        }
        .fullScreenCover(isPresented: .constant(!settings.hasOnboarded)) {
            OnboardingView()
        }
        .task {
            // Returning users: re-assert perms quietly. First-run perms are driven
            // by the onboarding flow instead, so don't prompt over it.
            guard settings.hasOnboarded else { return }
            model.location.requestWhenInUse()
            NotificationScheduler.requestAuthorization()
        }
    }
}

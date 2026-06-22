import SwiftUI
import iUXiOS

/// The app's top-level tabs. Held in `AppModel` so a screen can jump the user to
/// another tab programmatically. Routing lives on the Map now, so the old Routes
/// tab is gone and its place is taken by Settings.
enum AppTab: Hashable {
    case map, safety, contacts, profile, settings
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

            SafetyView()
                .tabItem { Label("Safety", systemImage: "shield.lefthalf.filled") }
                .tag(AppTab.safety)

            ContactsView()
                .tabItem { Label("Contacts", systemImage: "person.2.fill") }
                .tag(AppTab.contacts)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "cross.case.fill") }
                .tag(AppTab.profile)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
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

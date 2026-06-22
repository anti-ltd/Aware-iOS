import SwiftUI
import iUXiOS

/// Emergency medical info + app preferences + the privacy stance. The medical
/// profile is stored locally and only surfaced when the user chooses to.
struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @FocusState private var fieldFocused: Bool

    var body: some View {
        @Bindable var model = model
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section {
                    field("Full name", text: $model.profile.fullName)
                    field("Blood type", text: $model.profile.bloodType)
                    field("Allergies", text: $model.profile.allergies)
                    field("Conditions", text: $model.profile.conditions)
                    field("Medications", text: $model.profile.medications)
                    field("Notes", text: $model.profile.notes)
                } header: {
                    Text("Emergency medical info")
                } footer: {
                    Text("Stored only on this device. Aware never uploads it or shares it without an explicit action from you.")
                }

                Section("Map & routes") {
                    Toggle("Prefer safer routes", isOn: $settings.preferSaferRoutes)
                    Toggle("Show crime heatmap", isOn: $settings.showCrimeHeatmap)
                }

                Section("Safety") {
                    Toggle("SOS uses background location", isOn: $settings.sosUsesBackgroundLocation)
                }

                Section {
                    LabeledContent("Emergency number", value: EmergencyServices.localNumber)
                } header: {
                    Text("Not an emergency service")
                } footer: {
                    Text("Aware is not a life-saving device and may fail when you need it most. In a real emergency, call \(EmergencyServices.localNumber).")
                }

                Section {
                    LabeledContent("Cost", value: "Free")
                    LabeledContent("Accounts", value: "None")
                    LabeledContent("Location data", value: "On-device")
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("Every feature designed to protect you is free. No subscriptions, no paywalls.")
                }

                Section("About") {
                    NavigationLink {
                        ChangelogView()
                    } label: {
                        Label("Changelog", systemImage: "list.bullet.rectangle")
                    }
                    Button {
                        settings.hasOnboarded = false
                    } label: {
                        Label("Replay intro", systemImage: "play.circle")
                    }
                    LabeledContent("Version", value: Self.appVersion)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { fieldFocused = false }
                }
            }
            .navigationTitle("Profile")
        }
    }

    private static var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(v) (\(b))"
    }

    private func field(_ label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            TextField("", text: text)
                .multilineTextAlignment(.trailing)
                .focused($fieldFocused)
        }
    }
}

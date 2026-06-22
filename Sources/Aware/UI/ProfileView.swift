import SwiftUI
import iUXiOS

/// Emergency medical info, stored locally and only surfaced when the user
/// chooses to. App preferences live on the Settings tab now.
struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @FocusState private var fieldFocused: Bool

    var body: some View {
        @Bindable var model = model
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

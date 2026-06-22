import SwiftUI
import iUXiOS

/// The private trusted-contacts roster. No public/social anything — just the
/// people who get your live location, SOS alerts and missed-check-in pings.
struct ContactsView: View {
    @Environment(AppModel.self) private var model

    @State private var showAdd = false
    @State private var showImport = false

    var body: some View {
        NavigationStack {
            Group {
                if model.contacts.isEmpty {
                    ScrollView {
                        EmptyStateCard(
                            symbol: "person.2.badge.plus",
                            title: "No trusted contacts yet",
                            message: "Add family or friends who should be alerted when you need help.",
                            actionLabel: "Add a contact") { showAdd = true }
                            .padding(UX.screenPadding)
                    }
                    .scrollContentBackground(.hidden)
                    .ambientBackground(tint: .accentColor)
                } else {
                    List {
                        ForEach(model.contacts) { contact in
                            row(contact)
                        }
                        .onDelete(perform: model.removeContacts)
                    }
                }
            }
            .navigationTitle("Contacts")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { showImport = true } label: {
                            Label("Import from Contacts", systemImage: "person.crop.circle.badge.plus")
                        }
                        Button { showAdd = true } label: {
                            Label("Add manually", systemImage: "square.and.pencil")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddContactSheet { model.addContact($0) }
                    .glassSheet()
            }
            .sheet(isPresented: $showImport) {
                ContactPicker { model.addContact($0) }
                    .ignoresSafeArea()
            }
        }
    }

    private func row(_ contact: TrustedContact) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.title)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.name).font(.headline)
                Text([contact.relationship, contact.phone].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if contact.notifyOnAlert {
                Image(systemName: "bell.fill")
                    .font(.caption)
                    .foregroundStyle(.tint)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct AddContactSheet: View {
    let onAdd: (TrustedContact) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var phone = ""
    @State private var relationship = ""
    @State private var notify = true
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Contact") {
                    TextField("Name", text: $name).focused($focused)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                        .focused($focused)
                    TextField("Relationship (optional)", text: $relationship).focused($focused)
                }
                Section {
                    Toggle("Alert on SOS & missed check-ins", isOn: $notify)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("New contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focused = false }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(TrustedContact(
                            name: name,
                            phone: phone,
                            relationship: relationship.isEmpty ? nil : relationship,
                            notifyOnAlert: notify))
                        dismiss()
                    }
                    .disabled(name.isEmpty || phone.isEmpty)
                }
            }
        }
    }
}

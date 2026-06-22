import SwiftUI
import ContactsUI

/// Wraps `CNContactPickerViewController` so a trusted contact can be imported
/// from the address book in one tap. Runs out-of-process, so it needs no
/// Contacts permission — the user picks, and only the chosen contact comes back.
struct ContactPicker: UIViewControllerRepresentable {
    var onPick: (TrustedContact) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let vc = CNContactPickerViewController()
        vc.delegate = context.coordinator
        // Only offer contacts that actually have a phone number to alert.
        vc.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
        return vc
    }

    func updateUIViewController(_ vc: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onPick: (TrustedContact) -> Void
        init(onPick: @escaping (TrustedContact) -> Void) { self.onPick = onPick }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            let name = CNContactFormatter.string(from: contact, style: .fullName)
                ?? [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
            let phone = contact.phoneNumbers.first?.value.stringValue ?? ""
            guard !phone.isEmpty else { return }
            onPick(TrustedContact(name: name.isEmpty ? phone : name, phone: phone))
        }
    }
}

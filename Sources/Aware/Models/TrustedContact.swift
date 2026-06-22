import Foundation

/// A person the user has chosen to share live location, SOS alerts and
/// missed-check-in notifications with. Private by design — there are no public
/// social features, so a contact is just a local record plus a way to reach them.
struct TrustedContact: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var phone: String
    /// Relationship label shown in the list ("Mum", "Flatmate", …). Optional.
    var relationship: String?
    /// Whether this contact is alerted automatically on SOS / missed check-ins.
    var notifyOnAlert: Bool = true

    init(id: UUID = UUID(), name: String, phone: String,
         relationship: String? = nil, notifyOnAlert: Bool = true) {
        self.id = id
        self.name = name
        self.phone = phone
        self.relationship = relationship
        self.notifyOnAlert = notifyOnAlert
    }
}

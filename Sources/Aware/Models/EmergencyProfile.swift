import Foundation

/// Medical and emergency information the user can choose to surface to
/// responders. Stored locally; never shared without an explicit action.
struct EmergencyProfile: Codable, Hashable {
    var fullName: String = ""
    var bloodType: String = ""
    var allergies: String = ""
    var conditions: String = ""
    var medications: String = ""
    /// Free-text in-case-of-emergency note (e.g. "ICE: call Mum first").
    var notes: String = ""

    /// True once the user has filled in anything worth showing.
    var hasContent: Bool {
        ![fullName, bloodType, allergies, conditions, medications, notes]
            .allSatisfy(\.isEmpty)
    }
}

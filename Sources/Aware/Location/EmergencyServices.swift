import Foundation

/// The local emergency-call number, derived from the device's region. Surfaced
/// in the safety disclaimer so users always see the number that actually works
/// where they are, not a hard-coded "911".
///
/// Fallback is 112 — the GSM standard, reachable on most mobile networks
/// worldwide and the single number across the EU.
enum EmergencyServices {
    /// General emergency number for the device's current region (police/fire/ambulance).
    static var localNumber: String {
        guard let region = Locale.current.region?.identifier.uppercased() else { return "112" }
        return numbersByRegion[region] ?? "112"
    }

    /// Region (ISO 3166-1 alpha-2) → primary general emergency number.
    /// Regions not listed fall back to 112.
    private static let numbersByRegion: [String: String] = [
        // North America
        "US": "911", "CA": "911", "MX": "911",
        // UK & Ireland (112 also works, 999 is the established number)
        "GB": "999", "IE": "999",
        // Oceania
        "AU": "000", "NZ": "111",
        // Asia
        "JP": "110", "CN": "110", "KR": "112", "IN": "112",
        "HK": "999", "SG": "999", "MY": "999", "TW": "110",
        "TH": "191", "ID": "112", "PH": "911", "VN": "113",
        // Middle East
        "AE": "999", "SA": "999", "IL": "100", "TR": "112",
        // Africa
        "ZA": "112", "NG": "112", "EG": "122", "KE": "999",
        // Latin America
        "BR": "190", "AR": "911", "CL": "133", "CO": "123",
        // Europe uses 112 universally → covered by fallback
    ]
}

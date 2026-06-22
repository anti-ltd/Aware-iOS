import CoreLocation
import Foundation

/// Builds the SMS text Aware sends to trusted contacts. Pure value type so it's
/// trivial to unit-test and reuse across SOS, live sharing and missed check-ins.
enum AlertKind {
    case sos
    case sharing
    case missedCheckIn

    var lead: String {
        switch self {
        case .sos:           return "🆘 SOS — I need help."
        case .sharing:       return "📍 I'm sharing my live location with you via Aware."
        case .missedCheckIn: return "⚠️ I didn't check in safe on Aware. Please check on me."
        }
    }
}

enum AlertMessage {
    /// The full SMS body for `kind`, appending an Apple Maps link when a fix is
    /// available. Recipients see a tappable map pin to your last known position.
    static func body(kind: AlertKind, coordinate: CLLocationCoordinate2D?) -> String {
        var parts = [kind.lead]
        if let c = coordinate {
            let lat = String(format: "%.5f", c.latitude)
            let lng = String(format: "%.5f", c.longitude)
            parts.append("My location: https://maps.apple.com/?ll=\(lat),\(lng)&q=My%20location")
        } else {
            parts.append("(Location not available yet — turn on Aware's location access.)")
        }
        parts.append("— Sent from Aware")
        return parts.joined(separator: "\n\n")
    }
}

import Foundation

/// The kinds of active safety state Aware can be in. Exactly one runs at a time;
/// `.idle` is the resting state.
enum SafetyState: Equatable, Codable {
    /// Nothing active.
    case idle
    /// Live location is being shared with trusted contacts until the user stops.
    case sharing(startedAt: Date)
    /// A check-in timer is counting down; if it expires without "I'm safe",
    /// trusted contacts are alerted with the last known location.
    case timer(deadline: Date)
    /// SOS is active — broadcasting location and alerting contacts.
    case sos(startedAt: Date)

    var isActive: Bool { self != .idle }
}

/// Reasons a safety timer was started — drives the default duration and the
/// copy shown to contacts on expiry.
enum CheckInReason: String, CaseIterable, Identifiable {
    case walkingHome   = "Walking home"
    case publicTransport = "Public transport"
    case firstDate     = "First date"
    case unfamiliarArea = "Unfamiliar area"
    case other         = "Other"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .walkingHome:     return "figure.walk"
        case .publicTransport: return "tram.fill"
        case .firstDate:       return "heart.fill"
        case .unfamiliarArea:  return "map.fill"
        case .other:           return "clock.fill"
        }
    }

    /// Sensible default countdown for this scenario.
    var defaultDuration: TimeInterval {
        switch self {
        case .walkingHome:     return 20 * 60
        case .publicTransport: return 45 * 60
        case .firstDate:       return 2 * 60 * 60
        case .unfamiliarArea:  return 30 * 60
        case .other:           return 30 * 60
        }
    }
}

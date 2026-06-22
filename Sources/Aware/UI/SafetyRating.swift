import SwiftUI

/// A coarse safety band from nearby reported-crime density. Labelling, not
/// science. Shared by the current-area pill and the per-route ratings so they
/// all speak the same language and colour.
struct SafetyRating {
    let label: String
    let color: Color
    let symbol: String
    /// 0 (worst) … 100 (best), for ranking routes against each other.
    let score: Int

    /// No crime data loaded for here yet — shown muted so we never imply "safe"
    /// when we simply don't know.
    static let unknown = SafetyRating(label: "No data", color: .secondary,
                                      symbol: "questionmark.circle", score: -1)

    /// Band from a crime count measured inside a fixed area (a tapped spot, or the
    /// ring around the user).
    static func forArea(crimeCount n: Int) -> SafetyRating {
        switch n {
        case 0:       return .init(label: "All clear",  color: .green,  symbol: "checkmark.shield.fill",       score: 100)
        case 1...5:   return .init(label: "Low",        color: .green,  symbol: "shield.fill",                 score: 85)
        case 6...15:  return .init(label: "Moderate",   color: .yellow, symbol: "shield.lefthalf.filled",      score: 60)
        case 16...40: return .init(label: "High",       color: .orange, symbol: "exclamationmark.shield.fill", score: 35)
        default:      return .init(label: "Very high",  color: .red,    symbol: "exclamationmark.triangle.fill", score: 12)
        }
    }

    /// Band for a route from crimes passed per kilometre, so a long route isn't
    /// unfairly rated worse than a short one for covering more ground.
    static func forRoute(crimesPassed n: Int, distanceMeters: Double) -> SafetyRating {
        let perKm = Double(n) / max(distanceMeters / 1_000, 0.1)
        switch perKm {
        case ..<1:    return .init(label: "Very safe",   color: .green,  symbol: "checkmark.shield.fill",       score: 95)
        case ..<4:    return .init(label: "Safe",        color: .green,  symbol: "shield.fill",                 score: 78)
        case ..<10:   return .init(label: "Moderate",    color: .yellow, symbol: "shield.lefthalf.filled",      score: 55)
        case ..<20:   return .init(label: "Use caution", color: .orange, symbol: "exclamationmark.shield.fill", score: 32)
        default:      return .init(label: "Risky",       color: .red,    symbol: "exclamationmark.triangle.fill", score: 12)
        }
    }
}

/// Compact coloured capsule for a safety rating.
struct SafetyBadge: View {
    let rating: SafetyRating

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: rating.symbol)
            Text(rating.label)
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(rating.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(rating.color.opacity(0.18)))
    }
}

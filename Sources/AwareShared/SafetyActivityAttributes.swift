import ActivityKit
import Foundation

/// Live Activity descriptor for an active safety session. Compiled into both the
/// app (which starts/updates/ends the activity) and the widget extension (which
/// renders it on the lock screen and in the Dynamic Island).
public struct SafetyActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        /// "sos" | "sharing" | "timer" — kept as a string so the type stays
        /// trivially Codable across the process boundary.
        public var kind: String
        /// Countdown target, for the timer session only.
        public var deadline: Date?
        public var startedAt: Date

        public init(kind: String, deadline: Date?, startedAt: Date) {
            self.kind = kind
            self.deadline = deadline
            self.startedAt = startedAt
        }
    }

    public init() {}
}

/// Presentation helpers shared by both targets so the lock screen and the
/// Dynamic Island read consistently.
public extension SafetyActivityAttributes.ContentState {
    var title: String {
        switch kind {
        case "sos":     return "SOS active"
        case "sharing": return "Sharing location"
        case "timer":   return "Check-in timer"
        default:        return "Aware"
        }
    }
    var symbol: String {
        switch kind {
        case "sos":     return "sos"
        case "sharing": return "dot.radiowaves.left.and.right"
        case "timer":   return "timer"
        default:        return "shield.lefthalf.filled"
        }
    }
}

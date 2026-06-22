import ActivityKit
import Foundation

/// Starts, updates and ends the safety Live Activity. No-ops gracefully when the
/// user has Live Activities disabled or on an unsupported device.
///
/// Deliberately **not** actor-isolated. ActivityKit's `Activity.update`/`end`
/// are `nonisolated async` on the non-`Sendable` `Activity` type; awaiting them
/// from an isolated (`@MainActor`) context makes Swift 6 treat the handle as
/// "sent" across an isolation boundary and errors. Keeping the whole controller
/// nonisolated removes the boundary. The single stored handle is only ever
/// touched through these `await`-serialised calls, so `nonisolated(unsafe)` is
/// sound here.
enum LiveActivityController {
    nonisolated(unsafe) private static var current: Activity<SafetyActivityAttributes>?

    static func start(_ state: SafetyActivityAttributes.ContentState) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        await endAll()   // only ever one session live
        current = try? Activity.request(
            attributes: SafetyActivityAttributes(),
            content: .init(state: state, staleDate: nil))
    }

    static func update(_ state: SafetyActivityAttributes.ContentState) async {
        guard let current else { return }
        await current.update(.init(state: state, staleDate: nil))
    }

    static func end() async {
        let ending = current
        current = nil
        await ending?.end(nil, dismissalPolicy: .immediate)
    }

    private static func endAll() async {
        for activity in Activity<SafetyActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}

import ActivityKit
import WidgetKit
import SwiftUI

/// Lock-screen + Dynamic Island presentation of an active Aware safety session.
struct SafetyLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SafetyActivityAttributes.self) { context in
            lockScreen(context.state)
                .padding(16)
                .activityBackgroundTint(tint(context.state).opacity(0.18))
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(state.title, systemImage: state.symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint(state))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    trailing(state).font(.caption.weight(.bold))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(subtitle(state))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: state.symbol).foregroundStyle(tint(state))
            } compactTrailing: {
                trailing(state)
            } minimal: {
                Image(systemName: state.symbol).foregroundStyle(tint(state))
            }
        }
    }

    private func lockScreen(_ state: SafetyActivityAttributes.ContentState) -> some View {
        HStack(spacing: 14) {
            Image(systemName: state.symbol)
                .font(.title)
                .foregroundStyle(tint(state))
            VStack(alignment: .leading, spacing: 2) {
                Text(state.title).font(.headline)
                Text(subtitle(state)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            trailing(state).font(.title3.weight(.bold).monospacedDigit())
        }
    }

    @ViewBuilder
    private func trailing(_ state: SafetyActivityAttributes.ContentState) -> some View {
        if let deadline = state.deadline {
            Text(timerInterval: state.startedAt...deadline, countsDown: true)
                .monospacedDigit()
                .foregroundStyle(tint(state))
        } else {
            Image(systemName: "circle.fill")
                .font(.system(size: 8))
                .foregroundStyle(tint(state))
        }
    }

    private func subtitle(_ state: SafetyActivityAttributes.ContentState) -> String {
        switch state.kind {
        case "sos":     return "Contacts alerted with your location"
        case "sharing": return "Trusted contacts can follow you"
        case "timer":   return "Confirm you're safe before it ends"
        default:        return "Aware"
        }
    }

    private func tint(_ state: SafetyActivityAttributes.ContentState) -> Color {
        switch state.kind {
        case "sos":     return .red
        case "timer":   return .orange
        default:        return .teal
        }
    }
}

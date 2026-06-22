import Foundation
import Observation

/// App-wide runtime + persisted state. Owns the location stream, the trusted-
/// contact roster, the emergency profile, and the single active safety session.
///
/// Persistence is deliberately plain JSON in `UserDefaults`: no account, no
/// server, no cloud — the data never leaves the device unless the user shares it.
@MainActor
@Observable
final class AppModel {
    let location = LocationManager()

    var contacts: [TrustedContact] {
        didSet { persist(contacts, key: Keys.contacts) }
    }
    var profile: EmergencyProfile {
        didSet { persist(profile, key: Keys.profile) }
    }

    /// Which tab is showing. Mutable so screens can hand off (Routes search →
    /// Map). Not persisted — always boot on the map.
    var selectedTab: AppTab = .map

    /// The one active safety session (sharing / timer / SOS), or `.idle`.
    /// Persisted so a session — and its countdown — survives an app relaunch.
    private(set) var safety: SafetyState = .idle {
        didSet { persist(safety, key: Keys.safety) }
    }

    /// Set when a check-in timer has lapsed and the user hasn't confirmed safe —
    /// the UI surfaces a prompt to alert contacts or stand down. Not persisted.
    var pendingMissedCheckIn = false

    private let defaults: UserDefaults
    private enum Keys {
        static let contacts = "trustedContacts"
        static let profile  = "emergencyProfile"
        static let safety   = "safetyState"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        contacts = Self.load([TrustedContact].self, key: Keys.contacts, from: defaults) ?? []
        profile  = Self.load(EmergencyProfile.self, key: Keys.profile, from: defaults) ?? EmergencyProfile()
        safety   = Self.load(SafetyState.self, key: Keys.safety, from: defaults) ?? .idle

        // Resume a session that was live when the app was last quit.
        if safety.isActive {
            location.startStreaming()
            startActivity()
        }
        if case .timer(let deadline) = safety {
            NotificationScheduler.scheduleCheckIn(deadline: deadline)
        }
    }

    // MARK: Trusted contacts

    func addContact(_ contact: TrustedContact) { contacts.append(contact) }

    func removeContacts(at offsets: IndexSet) { contacts.remove(atOffsets: offsets) }

    /// Contacts that opted into automatic alerts — who SOS / missed check-ins ping.
    var alertContacts: [TrustedContact] { contacts.filter(\.notifyOnAlert) }

    // MARK: Safety sessions

    func startSharing() {
        safety = .sharing(startedAt: .now)
        location.startStreaming()
        startActivity()
    }

    func startTimer(_ duration: TimeInterval) {
        let deadline = Date.now.addingTimeInterval(duration)
        safety = .timer(deadline: deadline)
        location.startStreaming()
        NotificationScheduler.scheduleCheckIn(deadline: deadline)
        startActivity()
    }

    func triggerSOS() {
        safety = .sos(startedAt: .now)
        location.requestAlways()
        location.startStreaming()
        startActivity()
    }

    /// "I'm safe" — clears whatever session is running.
    func standDown() {
        safety = .idle
        pendingMissedCheckIn = false
        location.stopStreaming()
        NotificationScheduler.cancelCheckIn()
        Task { await LiveActivityController.end() }
    }

    /// Call when the app becomes active: if a check-in timer has lapsed, raise
    /// the missed-check-in prompt so the user can alert contacts or stand down.
    func evaluateTimer() {
        if case .timer(let deadline) = safety, Date.now >= deadline {
            pendingMissedCheckIn = true
        }
    }

    // MARK: Live Activity

    private func startActivity() {
        guard let state = activityState(for: safety) else { return }
        Task { await LiveActivityController.start(state) }
    }

    private func activityState(for state: SafetyState) -> SafetyActivityAttributes.ContentState? {
        switch state {
        case .idle:                  return nil
        case .sos(let started):      return .init(kind: "sos", deadline: nil, startedAt: started)
        case .sharing(let started):  return .init(kind: "sharing", deadline: nil, startedAt: started)
        case .timer(let deadline):   return .init(kind: "timer", deadline: deadline, startedAt: .now)
        }
    }

    // MARK: Persistence helpers

    private func persist<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String,
                                           from defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

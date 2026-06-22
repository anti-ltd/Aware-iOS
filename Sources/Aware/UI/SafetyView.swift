import SwiftUI
import Combine
import iUXiOS

/// The safety hub: SOS, live sharing and the check-in timer. Built for use under
/// stress — one big primary control, minimal interaction, an unmistakable
/// "stand down" once a session is live.
struct SafetyView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    @State private var showTimerSheet = false
    @State private var alert: AlertPayload?
    @State private var cantSend = false

    /// While the app is open, poll so a timer that lapses on-screen still trips
    /// the missed-check-in prompt without waiting for a background notification.
    private let ticker = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            ScrollView {
                VStack(spacing: UX.cardSpacing) {
                    if model.safety.isActive {
                        activeSessionCard
                    }

                    sosCard
                    sharingCard
                    timerCard

                    if model.alertContacts.isEmpty {
                        EmptyStateCard(
                            symbol: "person.2.slash",
                            title: "No trusted contacts",
                            message: "Add people in the Contacts tab so Aware can alert them during an SOS or a missed check-in.")
                    }
                }
                .padding(UX.screenPadding)
            }
            .scrollContentBackground(.hidden)
            .ambientBackground(tints: [.red, .accentColor])
            .navigationTitle("Safety")
            .sheet(isPresented: $showTimerSheet) {
                TimerSetupSheet { duration in
                    model.startTimer(duration)
                    showTimerSheet = false
                }
                .glassSheet()
            }
            .sheet(item: $alert) { payload in
                MessageComposer(recipients: payload.recipients, body: payload.body)
                    .ignoresSafeArea()
            }
            .alert("Can't send alerts", isPresented: $cantSend) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(model.alertContacts.isEmpty
                     ? "Add a trusted contact (with a phone number) first."
                     : "This device can't send SMS. The safety session is still active.")
            }
            .confirmationDialog("Check-in missed",
                                isPresented: $model.pendingMissedCheckIn,
                                titleVisibility: .visible) {
                Button("Alert my contacts", role: .destructive) {
                    model.pendingMissedCheckIn = false
                    fire(.missedCheckIn)
                }
                Button("I'm safe", role: .cancel) { model.standDown() }
            } message: {
                Text("Your safety timer ran out. Let your trusted contacts know, or confirm you're safe.")
            }
            .onAppear { model.evaluateTimer() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { model.evaluateTimer() }
            }
            .onReceive(ticker) { _ in model.evaluateTimer() }
        }
    }

    /// Start a session, then open a pre-filled SMS to the alert contacts. Falls
    /// back to an explanatory alert if there's no one to text or the device can't
    /// send SMS — the session stays active either way.
    private func fire(_ kind: AlertKind) {
        let recipients = model.alertContacts.map(\.phone).filter { !$0.isEmpty }
        guard !recipients.isEmpty, MessageComposer.canSend else {
            cantSend = true
            return
        }
        let body = AlertMessage.body(kind: kind, coordinate: model.location.location?.coordinate)
        alert = AlertPayload(recipients: recipients, body: body)
    }

    // MARK: Active session

    @ViewBuilder private var activeSessionCard: some View {
        CardSection {
            VStack(spacing: 14) {
                switch model.safety {
                case .sos(let started):
                    sessionHeader("SOS active", symbol: "sos", tint: .red,
                                  detail: "Since \(started.formatted(date: .omitted, time: .shortened))")
                case .sharing(let started):
                    sessionHeader("Sharing live location", symbol: "dot.radiowaves.left.and.right", tint: .accentColor,
                                  detail: "Since \(started.formatted(date: .omitted, time: .shortened))")
                case .timer(let deadline):
                    VStack(spacing: 6) {
                        sessionHeader("Check-in timer", symbol: "timer", tint: .orange, detail: nil)
                        CountdownText(until: deadline, style: .timer)
                            .font(.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())
                    }
                case .idle:
                    EmptyView()
                }

                Button {
                    model.standDown()
                } label: {
                    Label("I'm safe — stand down", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .glassPill(tint: .green, shadow: true)
                .foregroundStyle(.green)
            }
        }
    }

    private func sessionHeader(_ title: String, symbol: String, tint: Color, detail: String?) -> some View {
        VStack(spacing: 4) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(tint)
            if let detail {
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Controls

    private var sosCard: some View {
        Button {
            model.triggerSOS()
            fire(.sos)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "sos")
                    .font(.system(size: 44, weight: .heavy))
                Text("Hold-free SOS")
                    .font(.headline)
                Text("Broadcast your location and alert your contacts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
        .buttonStyle(.plain)
        .glassCard(tint: .red, shadow: true)
        .foregroundStyle(.red)
        .disabled(model.safety.isActive)
        .opacity(model.safety.isActive ? 0.4 : 1)
    }

    private var sharingCard: some View {
        Button {
            model.startSharing()
            fire(.sharing)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Share live location").font(.headline)
                    Text("Let trusted contacts follow your journey")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding(16)
        }
        .buttonStyle(.plain)
        .glassCard()
        .foregroundStyle(.primary)
        .disabled(model.safety.isActive)
        .opacity(model.safety.isActive ? 0.4 : 1)
    }

    private var timerCard: some View {
        Button {
            showTimerSheet = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "timer")
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Safety check-in timer").font(.headline)
                    Text("Alert contacts if you don't confirm you're safe")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding(16)
        }
        .buttonStyle(.plain)
        .glassCard()
        .foregroundStyle(.primary)
        .disabled(model.safety.isActive)
        .opacity(model.safety.isActive ? 0.4 : 1)
    }
}

/// Identifiable payload that drives the message-composer sheet.
private struct AlertPayload: Identifiable {
    let id = UUID()
    let recipients: [String]
    let body: String
}

/// Picks a check-in scenario (which seeds a sensible duration) and starts the
/// timer. Kept deliberately small — a couple of taps.
private struct TimerSetupSheet: View {
    let onStart: (TimeInterval) -> Void

    @State private var reason: CheckInReason = .walkingHome
    @State private var minutes: Double = CheckInReason.walkingHome.defaultDuration / 60

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: UX.cardSpacing) {
                    CardSection("What are you doing?") {
                        VStack(spacing: 0) {
                            ForEach(CheckInReason.allCases) { r in
                                Button {
                                    reason = r
                                    minutes = r.defaultDuration / 60
                                } label: {
                                    HStack {
                                        Label(r.rawValue, systemImage: r.symbol)
                                        Spacer()
                                        if reason == r {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(.tint)
                                        }
                                    }
                                    .padding(.vertical, UX.rowVPadding)
                                }
                                .buttonStyle(.plain)
                                if r != CheckInReason.allCases.last {
                                    Divider().opacity(0.4)
                                }
                            }
                        }
                    }

                    CardSection("Check in within") {
                        VStack(spacing: 8) {
                            Text("\(Int(minutes)) min")
                                .font(.title2.weight(.semibold).monospacedDigit())
                            Slider(value: $minutes, in: 5...180, step: 5)
                                .tint(.accentColor)
                        }
                        .padding(.vertical, 6)
                    }

                    Button {
                        onStart(minutes * 60)
                    } label: {
                        Label("Start timer", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                    .glassPill(tint: .accentColor)
                    .foregroundStyle(.tint)
                }
                .padding(UX.screenPadding)
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Safety timer")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

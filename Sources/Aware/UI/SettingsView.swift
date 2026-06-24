import SwiftUI
import UIKit
import CoreLocation
import iUXiOS

/// App settings — toggles plus an About section that matches Spot's info-doc pattern.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @State private var showWhatsNew = false

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            ScrollView {
                VStack(spacing: UX.cardSpacing) {
                    CardSection("About", accent: .accentColor, accentRule: true) {
                        NavRow("Changelog",
                               subtitle: "What's shipped in each build",
                               systemImage: "list.bullet.rectangle.fill", glyphTint: .orange) {
                            ChangelogPage()
                        }
                        Divider()
                        NavRow("Sources",
                               subtitle: "Open-data sources behind the map",
                               systemImage: "character.book.closed.fill", glyphTint: .purple) {
                            SourcesPage()
                        }
                        Divider()
                        NavRow("Coverage",
                               subtitle: "Where the crime heatmap works",
                               systemImage: "globe.americas.fill", glyphTint: .cyan) {
                            CoveragePage()
                        }
                        Divider()
                        NavRow("Privacy",
                               subtitle: "What Aware stores and sends",
                               systemImage: "hand.raised.fill", glyphTint: .pink) {
                            PrivacyPage()
                        }
                        Divider()
                        NavRow("Roadmap",
                               subtitle: "What's in the app today",
                               systemImage: "map", glyphTint: .mint) {
                            RoadmapPage()
                        }
                    }

                    CardSection("Routes & map", accent: .blue, accentRule: true) {
                        ToggleRow("Prefer safer routes",
                                  subtitle: "Weight by crime, lighting and service proximity",
                                  glyph: "shield.lefthalf.filled", glyphTint: .blue,
                                  isOn: $settings.preferSaferRoutes)
                        Divider().opacity(0.4)
                        ToggleRow("Show crime heatmap",
                                  subtitle: "Overlay reported-crime density on the map",
                                  glyph: "flame.fill", glyphTint: .orange,
                                  isOn: $settings.showCrimeHeatmap)
                    }

                    CardSection("Safety", accent: .red, accentRule: true) {
                        ToggleRow("SOS uses background location",
                                  subtitle: "Keep sharing your location after the screen locks",
                                  glyph: "location.fill", glyphTint: .red,
                                  isOn: $settings.sosUsesBackgroundLocation)
                    }

                    CardSection("Not an emergency service", accent: .pink, accentRule: true) {
                        infoRow("Emergency number", EmergencyServices.localNumber)
                        footer("Aware is not a life-saving device and may fail when you need it most. In a real emergency, call \(EmergencyServices.localNumber).")
                    }

                    CardSection("Replay", accent: .indigo, accentRule: true) {
                        permissionsRow
                        Divider().opacity(0.4)
                        Button {
                            settings.hasOnboarded = false
                        } label: {
                            HStack(spacing: 12) {
                                GlyphTile(systemName: "play.circle.fill", tint: .indigo, size: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Replay intro")
                                        .foregroundStyle(.primary)
                                    Text("Walk through onboarding again")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, UX.rowVPadding)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if ReleaseNotes.hasContent {
                            Divider().opacity(0.4)
                            ExtrasActionRow(
                                "What's New",
                                subtitle: "Highlights from the latest build",
                                systemImage: "sparkles",
                                glyphTint: .orange
                            ) { showWhatsNew = true }
                        }
                        Divider().opacity(0.4)
                        infoRow("Version", Self.appVersion)
                    }
                }
                .padding(UX.screenPadding)
            }
            .scrollContentBackground(.hidden)
            .ambientBackground(tint: .accentColor)
            .navigationTitle("Settings")
            .fullScreenCover(isPresented: $showWhatsNew) {
                WhatsNewView { showWhatsNew = false }
            }
        }
    }

    private var permissionsRow: some View {
        let granted = model.location.authorization == .authorizedWhenInUse
            || model.location.authorization == .authorizedAlways
        return Button {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 12) {
                GlyphTile(systemName: "lock.shield.fill", tint: .blue, size: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Permissions")
                        .foregroundStyle(.primary)
                    Text(granted ? "Location access granted" : "Location access needed for the map")
                        .font(.caption)
                        .foregroundStyle(granted ? Color.secondary : Color.red)
                }
                Spacer()
                Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(granted ? Color.accentColor : .red)
            }
            .padding(.vertical, UX.rowVPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.primary)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
        .padding(.vertical, UX.rowVPadding)
    }

    private func footer(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
            .padding(.bottom, UX.rowVPadding)
    }

    private static var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(v) (\(b))"
    }
}

private struct ExtrasActionRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let glyphTint: Color
    let action: () -> Void

    init(
        _ title: String,
        subtitle: String,
        systemImage: String,
        glyphTint: Color,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.glyphTint = glyphTint
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                GlyphTile(systemName: systemImage, tint: glyphTint, size: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, UX.rowVPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

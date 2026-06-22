import SwiftUI
import UIKit
import CoreLocation
import iUXiOS

/// App settings — the home every preference hangs off, styled like the flagship
/// Clink settings: a square-tile "General" grid up top for the navigable pages,
/// then signature glyph-headed sections (accent rule + colored tiles) for the
/// toggles and info. Routing moved onto the Map, so this took the old Routes tab
/// slot; the medical card stays on Profile.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(\.cardCornerRadius) private var cardCornerRadius

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            ScrollView {
                VStack(spacing: UX.cardSpacing) {
                    generalGrid

                    CardSection("Routes & map", glyph: "map.fill",
                                glyphTint: .blue, accent: .blue, accentRule: true) {
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

                    CardSection("Safety", glyph: "shield.fill",
                                glyphTint: .red, accent: .red, accentRule: true) {
                        ToggleRow("SOS uses background location",
                                  subtitle: "Keep sharing your location after the screen locks",
                                  glyph: "location.fill", glyphTint: .red,
                                  isOn: $settings.sosUsesBackgroundLocation)
                    }

                    CardSection("Privacy", glyph: "lock.fill",
                                glyphTint: .green, accent: .green, accentRule: true) {
                        infoRow("Cost", "Free")
                        Divider().opacity(0.4)
                        infoRow("Accounts", "None")
                        Divider().opacity(0.4)
                        infoRow("Location data", "On-device")
                        footer("Every feature designed to protect you is free. No subscriptions, no paywalls.")
                    }

                    CardSection("Not an emergency service", glyph: "phone.fill",
                                glyphTint: .pink, accent: .pink, accentRule: true) {
                        infoRow("Emergency number", EmergencyServices.localNumber)
                        footer("Aware is not a life-saving device and may fail when you need it most. In a real emergency, call \(EmergencyServices.localNumber).")
                    }

                    CardSection("About", glyph: "info.circle.fill",
                                glyphTint: .gray, accent: .gray, accentRule: true) {
                        Button {
                            settings.hasOnboarded = false
                        } label: {
                            HStack(spacing: 12) {
                                GlyphTile(systemName: "play.circle.fill", tint: .indigo, size: 28)
                                Text("Replay intro").foregroundStyle(.primary)
                                Spacer()
                            }
                            .padding(.vertical, UX.rowVPadding)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider().opacity(0.4)
                        infoRow("Version", Self.appVersion)
                    }
                }
                .padding(UX.screenPadding)
            }
            .scrollContentBackground(.hidden)
            .ambientBackground(tint: .accentColor)
            .navigationTitle("Settings")
        }
    }

    // MARK: General grid

    private var generalGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("General")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Rectangle().fill(Color.accentColor.opacity(0.4)).frame(height: 0.5)
            }
            LazyVGrid(columns: columns, spacing: 10) {
                permissionsTile
                navTile("Data sources", icon: "shield.lefthalf.filled", tint: .teal) { SourcesView() }
                navTile("Changelog", icon: "list.bullet.rectangle.fill", tint: .purple) { ChangelogView() }
            }
        }
    }

    /// Opens the app's iOS Settings pane; a corner tick reflects location access.
    private var permissionsTile: some View {
        let granted = model.location.authorization == .authorizedWhenInUse
            || model.location.authorization == .authorizedAlways
        return Button {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        } label: {
            tileBody(label: "Permissions", icon: "lock.shield.fill", tint: .blue)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(granted ? Color.accentColor : .red)
                        .padding(7)
                }
        }
        .buttonStyle(.plain)
    }

    private func navTile<D: View>(_ label: String, icon: String, tint: Color,
                                  @ViewBuilder destination: @escaping () -> D) -> some View {
        NavigationLink {
            destination()
        } label: {
            tileBody(label: label, icon: icon, tint: tint)
        }
        .buttonStyle(.plain)
    }

    private func tileBody(label: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 10) {
            GlyphTile(systemName: icon, tint: tint, size: 46)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(8)
        .aspectRatio(1, contentMode: .fit)
        .background {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        }
        .overlay {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(UX.Glass.outlineOpacity),
                              lineWidth: UX.Glass.outlineWidth)
        }
        .contentShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
    }

    // MARK: Rows

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

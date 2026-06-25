/**
 Settings → Service status — live operational view of map services and the crime relay.
 */
import SwiftUI
import iUXiOS

struct StatusPage: View {
    @State private var snapshot = ServiceStatusCatalog.Snapshot(
        catalogVersion: "…",
        generatedAt: nil,
        relayHealthy: true,
        apiKeyState: .missing,
        groups: [],
        isRemote: false)
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(spacing: UX.cardSpacing) {
                summaryCard
                ForEach(snapshot.groups) { group in
                    CardSection(group.title, accent: .accentColor, accentRule: true) {
                        ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                            if index > 0 { Divider() }
                            statusRow(item)
                        }
                    }
                }
            }
            .padding(UX.screenPadding)
        }
        .background {
            AmbientBackdrop(tint: .accentColor).ignoresSafeArea()
        }
        .navigationTitle("Service status")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await reload(force: true) }
        .task { await reload(force: false) }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(snapshot.summaryLine)
                        .font(.title3.weight(.semibold))
                    Text(relayHeadline)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                relayGlyph
            }

            HStack(spacing: 6) {
                Image(systemName: fetchFootnoteIcon)
                    .font(.caption2)
                Text(fetchFootnote)
                    .font(.caption)
                if let when = snapshot.generatedAt, snapshot.isRemote {
                    Text("·")
                    Text(when, style: .relative)
                        .font(.caption.monospacedDigit())
                }
            }
            .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .settingsCardChrome()
        .redacted(reason: isLoading && snapshot.groups.isEmpty ? .placeholder : [])
    }

    private var fetchFootnoteIcon: String {
        switch snapshot.apiKeyState {
        case .missing, .invalid: "key.slash"
        default: snapshot.isRemote ? "antenna.radiowaves.left.and.right" : "wifi.slash"
        }
    }

    private var fetchFootnote: String {
        switch snapshot.apiKeyState {
        case .missing:
            return snapshot.isRemote
                ? "Checked anti.ltd · key missing from app bundle"
                : "API key missing — set Secrets.xcconfig and rebuild"
        case .invalid:
            return "Checked anti.ltd · key rejected"
        case .valid:
            return snapshot.isRemote ? "Checked anti.ltd just now" : "Offline. Cached copy below."
        }
    }

    private var relayHeadline: String {
        switch snapshot.apiKeyState {
        case .missing: return "API key not configured"
        case .invalid: return "API key rejected"
        case .valid: return snapshot.relayHealthy ? "anti.ltd looks good" : "anti.ltd is down"
        }
    }

    private var relayGlyph: some View {
        Image(systemName: snapshot.relayReachable ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
            .font(.title2)
            .foregroundStyle(snapshot.relayReachable ? .green : .orange)
            .symbolRenderingMode(.hierarchical)
    }

    private func statusRow(_ item: ServiceStatusCatalog.Item) -> some View {
        HStack(alignment: .top, spacing: 12) {
            GlyphTile(systemName: item.symbol, tint: item.availability.tint)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(item.title)
                        .font(.body.weight(.semibold))
                    availabilityBadge(item.availability)
                    if item.viaAntiLtd, !item.availability.isDown {
                        Text("via anti.ltd")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.quaternary.opacity(0.65), in: Capsule())
                    }
                }
                if !item.availability.isDown {
                    Text(item.displayDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !item.availability.isDown, let regions = item.regions, !regions.isEmpty {
                    Text(regions.joined(separator: " · ").uppercased())
                        .font(.caption2.weight(.medium).monospaced())
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, UX.rowVPadding)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title), \(item.availability.label). \(item.displayDetail)")
    }

    private func availabilityBadge(_ availability: ServiceStatusCatalog.Availability) -> some View {
        Label(availability.label, systemImage: availability.symbol)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(availability.tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(availability.tint.opacity(0.14), in: Capsule())
            .labelStyle(.titleAndIcon)
    }

    private func reload(force: Bool) async {
        if !force { isLoading = true }
        snapshot = await ServiceStatusCatalog.load(force: force)
        isLoading = false
    }
}

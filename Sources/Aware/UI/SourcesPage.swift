/**
 Settings → Sources. Open-data feeds and on-device services behind the safety map.
 */
import SwiftUI
import iUXiOS

struct SourcesPage: View {
    @State private var remoteCrimeGroup: SourceGroup?

    private struct Source: Identifiable {
        let id: String
        let name: String
        let detail: String
        let url: String
        var cadence: String? = nil
        var nerd: String? = nil
        var viaAntiLtd: Bool = false
    }

    private struct SourceGroup {
        let title: String
        let glyph: String
        let tint: Color
        let sources: [Source]
    }

    private var displayGroups: [SourceGroup] {
        [Self.mapGroup] + (remoteCrimeGroup.map { [$0] } ?? [Self.legacyCrimeGroup])
    }

    private static let mapGroup = SourceGroup(
        title: "Maps, routes & search",
        glyph: "map.fill",
        tint: .blue,
        sources: [
            .init(id: "mapkit-tiles", name: "Map tiles & places",
                  detail: "Apple Maps. Powers the safety map and nearby services.",
                  url: "https://www.apple.com/maps"),
            .init(id: "mapkit-directions", name: "Safer-route directions",
                  detail: "Walking routes with optional crime weighting.",
                  url: "https://developer.apple.com/documentation/mapkit"),
            .init(id: "mapkit-search", name: "Place search",
                  detail: "Find destinations on the map.",
                  url: "https://developer.apple.com/documentation/mapkit"),
        ])

    private static let legacyCrimeGroup = SourceGroup(
        title: "Crime heatmap",
        glyph: "shield.fill",
        tint: .orange,
        sources: [
            .init(id: "police.uk", name: "police.uk",
                  detail: "UK street-level crime.", url: "https://data.police.uk",
                  cadence: "when you pan the map", viaAntiLtd: true),
            .init(id: "chicago", name: "City of Chicago",
                  detail: "Open crime data.", url: "https://data.cityofchicago.org",
                  cadence: "when you pan the map", viaAntiLtd: true),
            .init(id: "nyc", name: "City of New York",
                  detail: "Open crime data.", url: "https://data.cityofnewyork.us",
                  cadence: "when you pan the map", viaAntiLtd: true),
            .init(id: "sf", name: "City of San Francisco",
                  detail: "Open crime data.", url: "https://datasf.org",
                  cadence: "when you pan the map", viaAntiLtd: true),
            .init(id: "la", name: "City of Los Angeles",
                  detail: "Open crime data.", url: "https://data.lacity.org",
                  cadence: "when you pan the map", viaAntiLtd: true),
            .init(id: "baltimore", name: "Open Baltimore",
                  detail: "Baltimore City, Maryland.", url: "https://data.baltimorecity.gov",
                  cadence: "when you pan the map", viaAntiLtd: true),
            .init(id: "moco", name: "dataMontgomery",
                  detail: "Montgomery County, Maryland.", url: "https://data.montgomerycountymd.gov",
                  cadence: "when you pan the map", viaAntiLtd: true),
            .init(id: "pgc", name: "Prince George's County",
                  detail: "Maryland open data.", url: "https://data.princegeorgescountymd.gov",
                  cadence: "when you pan the map", viaAntiLtd: true),
        ])

    var body: some View {
        ScrollView {
            VStack(spacing: UX.cardSpacing) {
                ForEach(displayGroups, id: \.title) { group in
                    CardSection(group.title, accent: .accentColor, accentRule: true) {
                        ForEach(Array(group.sources.enumerated()), id: \.element.id) { index, source in
                            if index > 0 { Divider() }
                            sourceRow(source, glyph: group.glyph, tint: group.tint)
                        }
                    }
                }

                CardSection("How it works", accent: .accentColor, accentRule: true) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Crime feeds are free and need no key. Those rows come from anti.ltd and stay in sync with the server catalog.")
                        Text("Aware only fetches crime data for the map area you're looking at. Outside covered regions the map still works, just without a heatmap. See Coverage for the full list.")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, UX.rowVPadding)
                }
            }
            .padding(UX.screenPadding)
        }
        .background {
            AmbientBackdrop(tint: .accentColor)
                .ignoresSafeArea()
        }
        .navigationTitle("Sources")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await TrackingCatalogStore.refreshIfNeeded()
            guard let payload = await TrackingCatalogStore.sources(),
                  let crime = payload.groups.first(where: { $0.id == "crime" }) else { return }
            remoteCrimeGroup = SourceGroup(
                title: crime.title,
                glyph: "shield.fill",
                tint: .orange,
                sources: crime.sources.map {
                    Source(
                        id: $0.id,
                        name: $0.name,
                        detail: $0.detail,
                        url: $0.url,
                        cadence: $0.cadence,
                        nerd: Self.nerdHint($0.nerd),
                        viaAntiLtd: $0.relay == "anti.ltd")
                })
        }
    }

    @ViewBuilder private func sourceRow(_ source: Source, glyph: String, tint: Color) -> some View {
        Link(destination: URL(string: source.url)!) {
            HStack(alignment: .top, spacing: 12) {
                GlyphTile(systemName: glyph, tint: tint, size: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(source.name).foregroundStyle(.primary)
                    Text(source.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let cadence = source.cadence {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text(cadence)
                        }
                        .font(.caption2.weight(.medium).monospacedDigit())
                        .foregroundStyle(tint)
                        .padding(.top, 1)
                    }
                    if let nerd = source.nerd {
                        Text(nerd)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 1)
                    }
                    if source.viaAntiLtd {
                        HStack {
                            Spacer(minLength: 0)
                            AntiLtdRelayBadge()
                        }
                        .padding(.top, 4)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, UX.rowVPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private static func nerdHint(_ nerd: String?) -> String? {
        guard var text = nerd?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        let phrases = [
            ", relayed through anti.ltd.",
            ", relayed through anti.ltd",
            " relayed through anti.ltd.",
            "Relayed through anti.ltd. ",
            "Relayed through anti.ltd.",
            "Relayed through anti.ltd as GeoJSON.",
            "Relayed through anti.ltd as GeoJSON",
        ]
        for phrase in phrases {
            text = text.replacingOccurrences(of: phrase, with: "", options: .caseInsensitive)
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}

private struct AntiLtdRelayBadge: View {
    var body: some View {
        Text("via anti.ltd")
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.quaternary.opacity(0.65), in: Capsule())
    }
}

/**
 The "Data sources" page: an honest account of where every piece of data in
 Aware comes from. One glass card per source — what it powers, who provides it,
 and the privacy stance. Mirrors `ChangelogView`'s card layout.

 Keep this in sync with `CrimeService` (the crime providers) and the MapKit use
 in `RoutePlanner` / `PlaceSearch`.
 */
import SwiftUI
import iUXiOS

struct SourcesView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(Self.sources) { SourceCard(source: $0) }

                Text("Aware adds open-data sources city by city. Where none covers your area, the map still works — it just won't show a crime heatmap.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
            }
            .padding(16)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Data sources")
        .navigationBarTitleDisplayMode(.inline)
        .background {
            AmbientBackdrop(tint: .accentColor).ignoresSafeArea()
        }
    }

    static let sources: [DataSource] = [
        DataSource(
            id: 0,
            icon: "shield.lefthalf.filled",
            title: "Crime heatmap",
            subtitle: "Free, key-less open-data feeds — fetched live for the area you're viewing.",
            providers: [
                "police.uk — UK street-level crime (England, Wales, Northern Ireland)",
                "City of Chicago open data",
                "City of New York open data",
                "City of San Francisco open data",
                "City of Los Angeles open data",
                "Open Baltimore — Baltimore City, Maryland",
                "dataMontgomery — Montgomery County, Maryland",
                "Prince George's County, Maryland open data",
            ],
            footnote: "Each source publishes its own data on its own schedule, so coverage and freshness vary by city. The active source is always credited on the map."
        ),
        DataSource(
            id: 1,
            icon: "map",
            title: "Maps, routes & search",
            subtitle: "Apple Maps (MapKit), built into iOS.",
            providers: [
                "Map tiles & places — Apple Maps",
                "Safer-route directions — MapKit Directions",
                "Place search — MapKit Local Search",
            ],
            footnote: "Routing and search run through Apple's privacy-preserving MapKit. Aware sends no identity with these requests."
        ),
        DataSource(
            id: 2,
            icon: "lock.iphone",
            title: "Your personal data",
            subtitle: "Never a \"source\" — it never leaves your device.",
            providers: [
                "Emergency medical profile — stored on-device only",
                "Trusted contacts — read from your address book on-device",
                "Location — used live, never uploaded by Aware",
            ],
            footnote: "No accounts, no servers, no analytics. Your data is shared only when you take an explicit action, like sending an SOS."
        ),
    ]
}

/// One documented source of data the app relies on.
struct DataSource: Identifiable {
    let id: Int
    let icon: String
    let title: String
    let subtitle: String
    let providers: [String]
    let footnote: String
}

private struct SourceCard: View {
    let source: DataSource

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: source.icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 28)
                Text(source.title)
                    .font(.headline)
                Spacer()
            }

            Text(source.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider().opacity(0.5)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(source.providers, id: \.self) { provider in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Circle().fill(.tint).frame(width: 4, height: 4)
                            .offset(y: -2)
                        Text(provider)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Text(source.footnote)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(tint: .accentColor)
    }
}

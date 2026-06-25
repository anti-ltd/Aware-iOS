/**
 Full-screen world map with polygon overlays for crime heatmap coverage.
 */
import SwiftUI
import MapKit
import iUXiOS

struct CoveragePage: View {
    @State private var camera: MapCameraPosition = .region(CrimeCoverage.worldRegion)
    @State private var dockExpanded = false
    @State private var regions: [CoverageRegion] = []
    @State private var regionGroups: [TrackingCatalogStore.CoverageLayerPayload.CountryGroup] = []
    @State private var layerSummary = CrimeCoverage.bundledSummary

    private var accent: Color { CrimeCoverage.tint }
    private var sortedRegions: [CoverageRegion] {
        regions.sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }

    private var groupedRegionCount: Int {
        regionGroups.reduce(0) { total, country in
            total + country.regions.count + (country.adminAreas?.reduce(0) { $0 + $1.regions.count } ?? 0)
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            coverageMap
            bottomDock
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Coverage")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            await TrackingCatalogStore.refreshIfNeeded()
            await loadCoverage()
        }
    }

    // MARK: Map

    private var coverageMap: some View {
        Map(position: $camera, interactionModes: [.pan, .zoom, .rotate]) {
            ForEach(regions) { region in
                MapPolygon(coordinates: region.ring)
                    .foregroundStyle(accent.opacity(0.30))
                    .stroke(accent.opacity(0.55), lineWidth: 1.2)
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .ignoresSafeArea()
    }

    // MARK: Bottom dock

    private let dockCardInset: CGFloat = 16

    private var bottomDock: some View {
        VStack(alignment: .leading, spacing: 10) {
            layerHeader
            regionCard
        }
        .padding(.horizontal, UX.screenPadding)
        .padding(.bottom, UX.screenPadding)
    }

    private var layerHeader: some View {
        HStack(spacing: 10) {
            GlyphTile(systemName: CrimeCoverage.symbol, tint: CrimeCoverage.tint, size: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(CrimeCoverage.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("Regional coverage")
                    .font(.caption)
                    .foregroundStyle(CrimeCoverage.tint.opacity(0.88))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, dockCardInset)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassTile(shadow: false)
        .clipShape(RoundedRectangle(cornerRadius: UX.Glass.tileRadius, style: .continuous))
    }

    private var regionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            expandToggle
            Text(layerSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(dockExpanded ? nil : 2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: dockExpanded)
            if dockExpanded {
                regionList
                    .padding(.top, 2)
                    .transition(.opacity)
            }
        }
        .padding(dockCardInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassTile(shadow: false)
        .clipShape(RoundedRectangle(cornerRadius: UX.Glass.tileRadius, style: .continuous))
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: dockExpanded)
    }

    private var expandToggle: some View {
        Button {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                dockExpanded.toggle()
            }
            Haptics.select()
        } label: {
            HStack(spacing: 8) {
                Text("\(regions.count) regions")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(accent.opacity(0.15), in: Capsule())
                Spacer(minLength: 0)
                Image(systemName: dockExpanded ? "chevron.down" : "chevron.up")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(dockExpanded ? "Collapse region list" : "Expand region list")
        .accessibilityHint("Shows every region in this layer")
    }

    @ViewBuilder
    private var regionList: some View {
        if !regionGroups.isEmpty {
            if regionListNeedsScroll {
                ScrollView(showsIndicators: false) {
                    groupedRegionList
                }
                .frame(maxHeight: 260)
            } else {
                groupedRegionList
            }
        } else if regionListNeedsScroll {
            ScrollView(showsIndicators: false) {
                regionGrid
            }
            .frame(maxHeight: 220)
        } else {
            regionGrid
        }
    }

    private var regionListNeedsScroll: Bool {
        if !regionGroups.isEmpty { return groupedRegionCount > 10 }
        return sortedRegions.count > 12
    }

    private var groupedRegionList: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(regionGroups) { country in
                VStack(alignment: .leading, spacing: 8) {
                    Text(country.label)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(accent)
                    if !country.regions.isEmpty {
                        regionRefGrid(country.regions)
                    }
                    ForEach(country.adminAreas ?? []) { admin in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(admin.label)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.leading, 2)
                            regionRefGrid(admin.regions)
                        }
                    }
                }
            }
        }
    }

    private func regionRefGrid(_ refs: [TrackingCatalogStore.CoverageLayerPayload.RegionRef]) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 148), spacing: 8, alignment: .leading)],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(refs) { ref in
                regionRefRow(ref)
            }
        }
    }

    private func regionRefRow(_ ref: TrackingCatalogStore.CoverageLayerPayload.RegionRef) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(accent.opacity(0.55))
                .frame(width: 10, height: 10)
            Text(ref.label)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var regionGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 148), spacing: 8, alignment: .leading)],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(sortedRegions) { region in
                regionRow(region)
            }
        }
    }

    private func regionRow(_ region: CoverageRegion) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(accent.opacity(0.55))
                .frame(width: 10, height: 10)
            Text(region.label)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func loadCoverage() async {
        await CoverageCatalog.prepare()
        regions = await CoverageCatalog.regions()
        regionGroups = await CoverageCatalog.regionGroups()
        layerSummary = await CoverageCatalog.summary()
    }
}

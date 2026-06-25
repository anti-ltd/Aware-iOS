/**
 Crime coverage footprints for Settings → Coverage.
 Fetches polygons from anti.ltd; caches locally between launches.
 */
import CoreLocation
import MapKit
import SwiftUI

enum CrimeCoverage {
    static let layerId = "crime"
    static let title = "Crime"
    static let symbol = "shield.fill"
    static let tint = Color.orange
    static let bundledSummary =
        "Open police data for the UK, US metros, and international cities with street-level feeds."

    static let worldRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 20, longitude: 10),
        span: MKCoordinateSpan(latitudeDelta: 120, longitudeDelta: 200))
}

struct CoverageRegion: Identifiable, Hashable {
    let id: String
    let label: String
    let ring: [CLLocationCoordinate2D]

    static func == (lhs: CoverageRegion, rhs: CoverageRegion) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum CoverageCatalog {
    static func summary() async -> String {
        if let remote = await TrackingCatalogStore.coverageLayer(CrimeCoverage.layerId)?.summary,
           !remote.isEmpty {
            return remote
        }
        return CrimeCoverage.bundledSummary
    }

    static func regionGroups() async -> [TrackingCatalogStore.CoverageLayerPayload.CountryGroup] {
        await TrackingCatalogStore.coverageLayer(CrimeCoverage.layerId)?.regionGroups ?? []
    }

    static func regions() async -> [CoverageRegion] {
        if let remote = await TrackingCatalogStore.coverageLayer(CrimeCoverage.layerId) {
            return mapRemote(remote)
        }
        return []
    }

    static func prepare() async {
        await TrackingCatalogStore.loadCoverageLayer(CrimeCoverage.layerId)
    }

    private static func mapRemote(_ remote: TrackingCatalogStore.CoverageLayerPayload) -> [CoverageRegion] {
        remote.regions.map { region in
            CoverageRegion(
                id: region.id,
                label: region.label,
                ring: region.ring.compactMap { pair in
                    guard pair.count >= 2 else { return nil }
                    return CLLocationCoordinate2D(latitude: pair[0], longitude: pair[1])
                })
        }
    }
}

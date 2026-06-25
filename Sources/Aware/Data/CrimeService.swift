import CoreLocation
import MapKit
import Observation

/// One reported crime, normalised across providers.
struct CrimePoint: Identifiable, Hashable {
    let id: String          // provider-prefixed so ids never collide
    let coordinate: CLLocationCoordinate2D
    let category: String

    static func == (lhs: CrimePoint, rhs: CrimePoint) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Picks the provider that covers the visible region and publishes its crimes
/// for the map's heatmap overlay. Crime data is relayed through anti.ltd.
@MainActor
@Observable
final class CrimeService {
    private(set) var points: [CrimePoint] = []
    private(set) var isLoading = false
    /// The active provider's name (for an on-map credit), or nil if none covers
    /// the visible area.
    private(set) var sourceName: String?

    private var lastCenter: CLLocationCoordinate2D?
    private var lastSpan: CLLocationDegrees = 0

    func load(region: MKCoordinateRegion) async {
        // Skip refetch on tiny pans/zooms.
        if let last = lastCenter,
           distance(last, region.center) < 500,
           abs(lastSpan - region.span.latitudeDelta) < region.span.latitudeDelta * 0.25 {
            return
        }
        lastCenter = region.center
        lastSpan = region.span.latitudeDelta

        guard Self.coversAnyProvider(region.center) else {
            points = []; sourceName = nil; return
        }

        isLoading = true
        defer { isLoading = false }
        let (fetched, source) = await Self.fetchRelayed(region: region)
        sourceName = source
        points = Self.downsample(fetched)
    }

    /// Cap the rendered overlay count. Hundreds of overlapping translucent
    /// MapCircles tank pan/zoom performance through overdraw; ~250 still reads as
    /// a dense heat field. Even stride so coverage stays spread out.
    private static let maxPoints = 250
    private static func downsample(_ all: [CrimePoint]) -> [CrimePoint] {
        guard all.count > maxPoints else { return all }
        let stride = Int((Double(all.count) / Double(maxPoints)).rounded(.up))
        return all.enumerated().compactMap { $0.offset % stride == 0 ? $0.element : nil }
    }

    private func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }
}

// MARK: - anti.ltd relay

private extension MKCoordinateRegion {
    var minLat: Double { center.latitude  - span.latitudeDelta  / 2 }
    var maxLat: Double { center.latitude  + span.latitudeDelta  / 2 }
    var minLng: Double { center.longitude - span.longitudeDelta / 2 }
    var maxLng: Double { center.longitude + span.longitudeDelta / 2 }
}

private struct CrimePointsResponse: Decodable {
    let points: [WirePoint]
    let source: String?

    struct WirePoint: Decodable {
        let id: String
        let lat: Double
        let lon: Double
        let category: String?
    }
}

private extension CrimeService {
    static func fetchRelayed(region: MKCoordinateRegion) async -> ([CrimePoint], String?) {
        let query: [URLQueryItem] = [
            .init(name: "n", value: String(region.maxLat)),
            .init(name: "w", value: String(region.minLng)),
            .init(name: "s", value: String(region.minLat)),
            .init(name: "e", value: String(region.maxLng)),
        ]
        guard let url = TrackingAPI.url(path: "crime/points", query: query) else { return ([], nil) }
        var req = TrackingAPI.authenticatedRequest(url: url)
        req.timeoutInterval = 20
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let payload = try? JSONDecoder().decode(CrimePointsResponse.self, from: data) else {
            return ([], nil)
        }
        let points = payload.points.map { row in
            CrimePoint(
                id: row.id,
                coordinate: CLLocationCoordinate2D(latitude: row.lat, longitude: row.lon),
                category: row.category ?? "crime")
        }
        return (points, payload.source)
    }

    /// Rough boxes for wired providers — skip the network when clearly out of coverage.
    static func coversAnyProvider(_ coordinate: CLLocationCoordinate2D) -> Bool {
        COVERAGE_BOXES.contains { box in
            coordinate.latitude >= box.minLat && coordinate.latitude <= box.maxLat
                && coordinate.longitude >= box.minLng && coordinate.longitude <= box.maxLng
        }
    }

    private struct CoverageBox {
        let minLat: Double
        let maxLat: Double
        let minLng: Double
        let maxLng: Double
    }

    private static let COVERAGE_BOXES: [CoverageBox] = [
        .init(minLat: 49.8, maxLat: 60.9, minLng: -8.7, maxLng: 1.9),   // UK
        .init(minLat: 41.64, maxLat: 42.03, minLng: -87.95, maxLng: -87.52), // Chicago
        .init(minLat: 40.49, maxLat: 40.92, minLng: -74.27, maxLng: -73.68), // NYC
        .init(minLat: 37.70, maxLat: 37.84, minLng: -122.53, maxLng: -122.35), // SF
        .init(minLat: 33.70, maxLat: 34.34, minLng: -118.67, maxLng: -118.15), // LA
        .init(minLat: 38.93, maxLat: 39.35, minLng: -77.53, maxLng: -76.88), // Montgomery Co
        .init(minLat: 38.53, maxLat: 39.10, minLng: -77.07, maxLng: -76.69), // Prince George's
        .init(minLat: 39.19, maxLat: 39.38, minLng: -76.72, maxLng: -76.52), // Baltimore
        .init(minLat: 47.49, maxLat: 47.73, minLng: -122.44, maxLng: -122.24), // Seattle
        .init(minLat: 38.79, maxLat: 38.99, minLng: -77.12, maxLng: -76.91), // Washington DC
        .init(minLat: 39.87, maxLat: 40.14, minLng: -75.28, maxLng: -74.95), // Philadelphia
        .init(minLat: 43.58, maxLat: 43.85, minLng: -79.64, maxLng: -79.11), // Toronto
    ]
}

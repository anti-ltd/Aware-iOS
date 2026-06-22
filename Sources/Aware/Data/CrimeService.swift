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

/// A regional open-data crime source. Each provider declares the geographic box
/// it covers and knows how to fetch normalised `CrimePoint`s for a visible map
/// region. Add a country/city by adding a provider — no other code changes.
protocol CrimeProvider: Sendable {
    /// Human label, for the map's "source" credit.
    var name: String { get }
    /// Rough bounding box this provider has data for.
    var bounds: MKMapRect { get }
    func fetch(region: MKCoordinateRegion) async -> [CrimePoint]
}

extension CrimeProvider {
    func covers(_ coordinate: CLLocationCoordinate2D) -> Bool {
        bounds.contains(MKMapPoint(coordinate))
    }
}

/// Picks the provider that covers the visible region and publishes its crimes
/// for the map's heatmap overlay. Free, key-less sources only.
@MainActor
@Observable
final class CrimeService {
    private(set) var points: [CrimePoint] = []
    private(set) var isLoading = false
    /// The active provider's name (for an on-map credit), or nil if none covers
    /// the visible area.
    private(set) var sourceName: String?

    private let providers: [CrimeProvider] = [UKPoliceProvider()] + SocrataProvider.cities

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

        guard let provider = providers.first(where: { $0.covers(region.center) }) else {
            points = []; sourceName = nil; return
        }
        sourceName = provider.name

        isLoading = true
        defer { isLoading = false }
        points = Self.downsample(await provider.fetch(region: region))
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

// MARK: - Region helpers

private extension MKCoordinateRegion {
    var minLat: Double { center.latitude  - span.latitudeDelta  / 2 }
    var maxLat: Double { center.latitude  + span.latitudeDelta  / 2 }
    var minLng: Double { center.longitude - span.longitudeDelta / 2 }
    var maxLng: Double { center.longitude + span.longitudeDelta / 2 }
}

/// Build an MKMapRect from corner lat/lngs (degrees).
private func mapRect(minLat: Double, maxLat: Double, minLng: Double, maxLng: Double) -> MKMapRect {
    let a = MKMapPoint(CLLocationCoordinate2D(latitude: maxLat, longitude: minLng))
    let b = MKMapPoint(CLLocationCoordinate2D(latitude: minLat, longitude: maxLng))
    return MKMapRect(x: min(a.x, b.x), y: min(a.y, b.y),
                     width: abs(a.x - b.x), height: abs(a.y - b.y))
}

// MARK: - UK: police.uk

/// UK street-level crime from the free, key-less police.uk API. Queries the
/// *visible polygon* so the heatmap fills the viewport (not just a 1-mile blob);
/// if the area is too big the API returns 503, so we fall back to the centre-
/// point query (~1-mile radius).
private struct UKPoliceProvider: CrimeProvider {
    let name = "police.uk"
    // Great Britain + NI, roughly.
    var bounds: MKMapRect { mapRect(minLat: 49.8, maxLat: 60.9, minLng: -8.7, maxLng: 1.9) }

    func fetch(region: MKCoordinateRegion) async -> [CrimePoint] {
        if let poly = await fetchPoly(region: region) { return poly }
        return await fetchPoint(center: region.center)
    }

    private func fetchPoly(region: MKCoordinateRegion) async -> [CrimePoint]? {
        // police.uk wants a "lat,lng:lat,lng:…" polygon. Use the viewport corners.
        let poly = [
            "\(region.maxLat),\(region.minLng)",
            "\(region.maxLat),\(region.maxLng)",
            "\(region.minLat),\(region.maxLng)",
            "\(region.minLat),\(region.minLng)",
        ].joined(separator: ":")

        var comps = URLComponents(string: "https://data.police.uk/api/crimes-street/all-crime")!
        comps.queryItems = [URLQueryItem(name: "poly", value: poly)]
        guard let url = comps.url,
              let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let decoded = try? JSONDecoder().decode([UKCrime].self, from: data)
        else { return nil }   // 503 (too large) or error → caller falls back
        return decoded.compactMap { $0.point }
    }

    private func fetchPoint(center: CLLocationCoordinate2D) async -> [CrimePoint] {
        var comps = URLComponents(string: "https://data.police.uk/api/crimes-street/all-crime")!
        comps.queryItems = [
            URLQueryItem(name: "lat", value: String(format: "%.4f", center.latitude)),
            URLQueryItem(name: "lng", value: String(format: "%.4f", center.longitude)),
        ]
        guard let url = comps.url,
              let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let decoded = try? JSONDecoder().decode([UKCrime].self, from: data)
        else { return [] }
        return decoded.compactMap { $0.point }
    }
}

private struct UKCrime: Decodable {
    let id: Int
    let category: String
    let location: Loc
    struct Loc: Decodable { let latitude: String; let longitude: String }

    var point: CrimePoint? {
        guard let lat = Double(location.latitude), let lng = Double(location.longitude) else { return nil }
        return CrimePoint(id: "uk-\(id)",
                          coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                          category: category)
    }
}

// MARK: - US cities: Socrata SODA (key-less)

/// Generic provider for any Socrata open-data crime dataset — free and key-less
/// (rate-limited without an app token, fine for occasional reads). Adding a city
/// is one entry in `cities`: host, resource id, the lat/lng/id/category column
/// names, and a bounding box.
private struct SocrataProvider: CrimeProvider {
    let name: String
    let host: String
    let resource: String
    let latField: String
    let lngField: String
    let idField: String
    let categoryField: String
    let idPrefix: String
    let bounds: MKMapRect

    func fetch(region: MKCoordinateRegion) async -> [CrimePoint] {
        // SoQL `between` on the numeric lat/lng columns, clamped to our bounds.
        let bb = bounds
        let nw = MKMapPoint(x: bb.minX, y: bb.minY).coordinate
        let se = MKMapPoint(x: bb.maxX, y: bb.maxY).coordinate
        let minLat = max(region.minLat, min(nw.latitude, se.latitude))
        let maxLat = min(region.maxLat, max(nw.latitude, se.latitude))
        let minLng = max(region.minLng, min(nw.longitude, se.longitude))
        let maxLng = min(region.maxLng, max(nw.longitude, se.longitude))
        guard minLat < maxLat, minLng < maxLng else { return [] }

        let whereClause = """
        \(latField) between \(minLat) and \(maxLat) \
        AND \(lngField) between \(minLng) and \(maxLng)
        """

        var comps = URLComponents(string: "https://\(host)/resource/\(resource).json")!
        comps.queryItems = [
            URLQueryItem(name: "$where", value: whereClause),
            URLQueryItem(name: "$select", value: "\(idField),\(categoryField),\(latField),\(lngField)"),
            URLQueryItem(name: "$limit", value: "600"),
        ]
        guard let url = comps.url,
              let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let rows = try? JSONDecoder().decode([[String: SODAValue]].self, from: data)
        else { return [] }

        return rows.compactMap { row -> CrimePoint? in
            guard let lat = row[latField]?.double, let lng = row[lngField]?.double else { return nil }
            let rid = row[idField]?.string ?? "\(lat),\(lng)"
            let cat = row[categoryField]?.string ?? "crime"
            return CrimePoint(id: "\(idPrefix)-\(rid)",
                              coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                              category: cat)
        }
    }

    /// Every wired Socrata city. Add a row to support a new one.
    static let cities: [SocrataProvider] = [
        SocrataProvider(name: "City of Chicago", host: "data.cityofchicago.org",
                        resource: "ijzp-q8t2", latField: "latitude", lngField: "longitude",
                        idField: "id", categoryField: "primary_type", idPrefix: "chi",
                        bounds: mapRect(minLat: 41.64, maxLat: 42.03, minLng: -87.95, maxLng: -87.52)),
        SocrataProvider(name: "City of New York", host: "data.cityofnewyork.us",
                        resource: "5uac-w243", latField: "latitude", lngField: "longitude",
                        idField: "cmplnt_num", categoryField: "ofns_desc", idPrefix: "nyc",
                        bounds: mapRect(minLat: 40.49, maxLat: 40.92, minLng: -74.27, maxLng: -73.68)),
        SocrataProvider(name: "City of San Francisco", host: "data.sfgov.org",
                        resource: "wg3w-h783", latField: "latitude", lngField: "longitude",
                        idField: "row_id", categoryField: "incident_category", idPrefix: "sf",
                        bounds: mapRect(minLat: 37.70, maxLat: 37.84, minLng: -122.53, maxLng: -122.35)),
        SocrataProvider(name: "City of Los Angeles", host: "data.lacity.org",
                        resource: "2nrs-mtv8", latField: "lat", lngField: "lon",
                        idField: "dr_no", categoryField: "crm_cd_desc", idPrefix: "la",
                        bounds: mapRect(minLat: 33.70, maxLat: 34.34, minLng: -118.67, maxLng: -118.15)),
    ]
}

/// A Socrata field value, which may arrive as a JSON string or number.
private enum SODAValue: Decodable {
    case string(String), number(Double), other

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { self = .string(s) }
        else if let d = try? c.decode(Double.self) { self = .number(d) }
        else { self = .other }
    }

    var string: String? {
        switch self {
        case .string(let s): return s
        case .number(let d): return String(d)
        case .other:         return nil
        }
    }
    var double: Double? {
        switch self {
        case .number(let d): return d
        case .string(let s): return Double(s)
        case .other:         return nil
        }
    }
}

import MapKit
import Observation

/// A nearby emergency-service place found on the map.
struct FoundPlace: Identifiable, Hashable, Sendable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let category: ServiceCategory

    static func == (lhs: FoundPlace, rhs: FoundPlace) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Runs MapKit points-of-interest searches for the selected service categories
/// over the visible region and publishes the results for the map to pin.
///
/// Uses `MKLocalPointsOfInterestRequest` (no natural-language query) so results
/// are a clean POI set filtered to the categories the user toggled on.
@MainActor
@Observable
final class PlaceSearch {
    private(set) var places: [FoundPlace] = []
    private(set) var isSearching = false

    private var searchToken = 0

    /// Search `categories` within `radius` metres of `center`. Categories with no
    /// POI mapping (taxi, generic 24-hour) are ignored. Debounce at the call site.
    ///
    /// Apple caps each `MKLocalPointsOfInterestRequest` at a couple dozen results
    /// regardless of radius, so a single wide search looks empty when zoomed out.
    /// To fill the visible area we tile it into a grid and run one search per cell,
    /// then merge and dedupe. More area → more cells → more pins.
    ///
    /// Cells run in small concurrent batches: firing all of them at once trips
    /// `MKErrorLoadingThrottled`, which `try?` would swallow into empty cells —
    /// the exact "nothing shows until I zoom way in" failure. Each batch's results
    /// are published as they land so pins stream in rather than all-or-nothing.
    func search(categories: Set<ServiceCategory>,
                center: CLLocationCoordinate2D,
                radius: CLLocationDistance) async {
        let poi = categories.flatMap(\.poiCategories)
        guard !poi.isEmpty else { places = []; return }

        searchToken &+= 1
        let token = searchToken
        // Capture only Sendable values across the task boundary (strict
        // concurrency): the POI categories as raw strings, rebuilt into a filter
        // inside each task. MKPointOfInterestFilter itself is not Sendable.
        let poiRaw = poi.map(\.rawValue)

        // Grid grows with the visible span (capped 4×4). Cell search radius is
        // the grid pitch with a little overlap so cells tile with no gaps.
        let dim = max(1, min(4, Int((radius / 7_000).rounded())))
        let cells = gridCenters(around: center, radius: radius, dim: dim)
        let pitch = dim > 1 ? radius * 2 / Double(dim) : radius
        let cellRadius = min(max(pitch * 0.72, 500), 50_000)

        isSearching = true
        defer { if token == searchToken { isSearching = false } }

        var merged: [String: FoundPlace] = [:]
        let batchSize = 4
        for start in stride(from: 0, to: cells.count, by: batchSize) {
            guard token == searchToken else { return }  // superseded mid-flight
            let batch = cells[start..<min(start + batchSize, cells.count)]
            let found = await withTaskGroup(of: [FoundPlace].self) { group in
                for cell in batch {
                    let lat = cell.latitude, lon = cell.longitude
                    group.addTask {
                        let filter = MKPointOfInterestFilter(including: poiRaw.map(MKPointOfInterestCategory.init(rawValue:)))
                        let request = MKLocalPointsOfInterestRequest(
                            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                            radius: cellRadius)
                        request.pointOfInterestFilter = filter
                        guard let response = try? await MKLocalSearch(request: request).start() else { return [] }
                        return response.mapItems.compactMap { item in
                            guard let cat = ServiceCategory.from(item.pointOfInterestCategory) else { return nil }
                            return FoundPlace(name: item.name ?? cat.title,
                                              coordinate: item.placemark.coordinate,
                                              category: cat)
                        }
                    }
                }
                var acc: [FoundPlace] = []
                for await f in group { acc.append(contentsOf: f) }
                return acc
            }
            for place in found {
                // Dedupe across overlapping cells by name + rounded coordinate.
                let key = "\(place.name)@\(Int(place.coordinate.latitude * 1e4))," +
                          "\(Int(place.coordinate.longitude * 1e4))"
                merged[key] = place
            }
            guard token == searchToken else { return }
            places = Array(merged.values)   // stream pins in batch-by-batch
        }
    }

    /// Even grid of cell centres covering a square `2*radius` wide around `center`.
    private func gridCenters(around center: CLLocationCoordinate2D,
                             radius: CLLocationDistance,
                             dim: Int) -> [CLLocationCoordinate2D] {
        guard dim > 1 else { return [center] }
        let latM = radius * 2 / Double(dim)          // cell pitch in metres
        let latStep = latM / 111_000
        let lonStep = latM / (111_000 * max(0.2, cos(center.latitude * .pi / 180)))
        let half = Double(dim - 1) / 2
        var out: [CLLocationCoordinate2D] = []
        for r in 0..<dim {
            for c in 0..<dim {
                out.append(.init(latitude: center.latitude + (Double(r) - half) * latStep,
                                 longitude: center.longitude + (Double(c) - half) * lonStep))
            }
        }
        return out
    }

    func clear() { places = [] }
}

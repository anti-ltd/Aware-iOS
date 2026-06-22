import MapKit
import Observation

/// Computes walking routes to a destination and picks the "safer" one when crime
/// data is available — the engine shared by the map's long-press routing and the
/// Routes tab's typed search.
///
/// "Safer" v1: request MapKit's alternate walking routes, then prefer the route
/// passing the fewest reported crimes (from the heatmap data) over the fastest.
/// A fuller model (lighting, population, time-of-day) layers on later.
@MainActor
@Observable
final class RoutePlanner {
    private(set) var destination: CLLocationCoordinate2D?
    private(set) var destinationName: String?
    private(set) var routes: [MKRoute] = []
    private(set) var selected: MKRoute?
    private(set) var isRouting = false
    /// The crime set the current routes were scored against — lets any view (the
    /// map or the Routes tab) render per-route ratings without holding its own copy.
    private(set) var crimePoints: [CrimePoint] = []
    /// Why `selected` won — shown on the route card.
    private(set) var reason: String?
    private(set) var errorText: String?

    func clear() {
        destination = nil; destinationName = nil
        routes = []; selected = nil; reason = nil; errorText = nil
        crimePoints = []
    }

    /// Compute routes from `from` to `to`, then choose one. `crime` is the
    /// currently-loaded heatmap points; `preferSafer` mirrors the user setting.
    func route(from: CLLocationCoordinate2D,
               to: CLLocationCoordinate2D,
               name: String?,
               preferSafer: Bool,
               crime: [CrimePoint]) async {
        destination = to
        destinationName = name
        errorText = nil
        isRouting = true
        defer { isRouting = false }

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        request.transportType = .walking
        request.requestsAlternateRoutes = true

        guard let response = try? await MKDirections(request: request).calculate(),
              !response.routes.isEmpty else {
            routes = []; selected = nil; reason = nil
            errorText = "Couldn't find a walking route there."
            return
        }

        routes = response.routes
        choose(preferSafer: preferSafer, crime: crime)
    }

    /// Re-pick the selected route (e.g. after the safer-routes toggle flips, or
    /// fresh crime data loads) without recomputing the geometry.
    func choose(preferSafer: Bool, crime: [CrimePoint]) {
        crimePoints = crime
        guard !routes.isEmpty else { selected = nil; reason = nil; return }
        if preferSafer, !crime.isEmpty {
            selected = routes.min { score($0, crime) < score($1, crime) }
            reason = "Fewest reported crimes nearby"
        } else {
            selected = routes.min { $0.expectedTravelTime < $1.expectedTravelTime }
            reason = preferSafer ? "Fastest (no crime data here)" : "Fastest route"
        }
    }

    /// Manually pick one of the computed routes (tapping a row on the route card).
    /// Holds until the geometry or crime set changes and `choose` re-picks.
    func select(_ route: MKRoute) {
        guard routes.contains(where: { $0 === route }) else { return }
        selected = route
        reason = "You picked this route"
    }

    /// Safety rating for a route against the cached crime set (`crimePoints`).
    func rating(for route: MKRoute) -> SafetyRating { rating(for: route, crime: crimePoints) }

    /// The routes we rerouted *away* from: non-selected alternates that land in a
    /// clearly-risky band and are worse than the route we picked. Drawn red on the
    /// map so the danger we avoided is visible, not just implied. Empty when there's
    /// no risky alternative to contrast against the choice.
    func dangerRoutes() -> [MKRoute] {
        guard let sel = selected, routes.count > 1, !crimePoints.isEmpty else { return [] }
        let selScore = rating(for: sel).score
        return routes.filter { r in
            guard r !== sel else { return false }
            let s = rating(for: r).score
            return s <= 32 && s < selScore   // "Use caution"/"Risky" and worse than ours
        }
    }

    /// Safety rating for a route, from how many reported crimes it passes per km.
    func rating(for route: MKRoute, crime: [CrimePoint]) -> SafetyRating {
        guard !crime.isEmpty else { return .unknown }
        return SafetyRating.forRoute(crimesPassed: score(route, crime),
                                     distanceMeters: route.distance)
    }

    /// Count crime points within ~60 m of the route's path (sampled coordinates).
    private func score(_ route: MKRoute, _ crime: [CrimePoint]) -> Int {
        let coords = route.polyline.sampledCoordinates(stride: 4)
        guard !coords.isEmpty else { return .max }
        var count = 0
        for point in crime {
            let pl = CLLocation(latitude: point.coordinate.latitude, longitude: point.coordinate.longitude)
            for c in coords {
                if pl.distance(from: CLLocation(latitude: c.latitude, longitude: c.longitude)) < 60 {
                    count += 1; break
                }
            }
        }
        return count
    }
}

extension MKPolyline {
    /// Every `stride`-th coordinate of the polyline — enough to score proximity
    /// without walking all of a dense path.
    func sampledCoordinates(stride: Int = 1) -> [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](
            repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        guard stride > 1 else { return coords }
        return coords.enumerated().compactMap { $0.offset % stride == 0 ? $0.element : nil }
    }
}

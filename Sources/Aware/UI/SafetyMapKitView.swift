import SwiftUI
import MapKit

/// Imperative camera move (recenter on the user, frame a route). Compared by `id`
/// so applying it once is idempotent across SwiftUI updates.
struct MapCommand: Equatable {
    let region: MKCoordinateRegion
    let id: Int
    static func == (l: MapCommand, r: MapCommand) -> Bool { l.id == r.id }
}

/// A `UIViewRepresentable` MKMapView — the safety map's renderer. SwiftUI `Map`
/// can't host a custom raster overlay, so the heatmap forces UIKit here. This
/// view owns the map content (heat overlay, service pins, route lines); the
/// chrome (filter bar, toggle, cards) stays SwiftUI in `SafetyMapView`.
struct SafetyMapKitView: UIViewRepresentable {
    var heat: HeatImage?
    var places: [FoundPlace]
    var routes: [MKRoute]
    var selectedRoute: MKRoute?
    /// Non-selected routes that pass through danger — drawn red.
    var dangerRoutes: [MKRoute]
    var destination: CLLocationCoordinate2D?
    var destinationName: String?
    var showsUserLocation: Bool
    var command: MapCommand?
    var onRegionChange: (MKCoordinateRegion) -> Void
    var onLongPress: (CLLocationCoordinate2D) -> Void
    var onTap: (CLLocationCoordinate2D) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = showsUserLocation
        map.showsCompass = true
        map.pointOfInterestFilter = .excludingAll
        map.mapType = .standard
        // Seed a modest region so the first load isn't a world-wide POI search;
        // `SafetyMapView` recenters on the user the moment a fix arrives.
        map.setRegion(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
            latitudinalMeters: 4_000, longitudinalMeters: 4_000), animated: false)
        context.coordinator.map = map

        let press = UILongPressGestureRecognizer(target: context.coordinator,
                                                 action: #selector(Coordinator.handleLongPress(_:)))
        press.minimumPressDuration = 0.4
        map.addGestureRecognizer(press)

        // Insights is a *double* tap so it doesn't fight the long-press route
        // gesture (a single tap can land while you're settling into a hold).
        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleTap(_:)))
        tap.numberOfTapsRequired = 2
        tap.delegate = context.coordinator
        map.addGestureRecognizer(tap)

        // Keep MapKit's own double-tap-to-zoom from also firing on our insight
        // double-tap: make any existing double-tap recognizer wait for ours to
        // fail, so an empty-map double-tap opens insights instead of zooming.
        for gr in map.allGestureRecognizers() {
            if let t = gr as? UITapGestureRecognizer, t !== tap, t.numberOfTapsRequired == 2 {
                t.require(toFail: tap)
            }
        }
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let c = context.coordinator
        c.parent = self
        if map.showsUserLocation != showsUserLocation { map.showsUserLocation = showsUserLocation }
        c.syncHeat(heat, on: map)
        c.syncPlaces(places, on: map)
        c.syncRoutes(routes, selected: selectedRoute, danger: dangerRoutes,
                     destination: destination, name: destinationName, on: map)
        if let command, command.id != c.lastCommandID {
            c.lastCommandID = command.id
            map.setRegion(command.region, animated: true)
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var parent: SafetyMapKitView
        weak var map: MKMapView?

        private var heatVersion: Int?
        private var heatOverlay: CrimeHeatOverlay?
        private var placeAnnos: [String: PlaceAnnotation] = [:]
        private var routeOverlays: [MKPolyline] = []
        private var selectedOverlay: MKPolyline?
        /// Polylines (by identity) of routes that pass through danger — rendered red.
        private var dangerOverlays: Set<ObjectIdentifier> = []
        private var destAnno: DestinationAnnotation?
        var lastCommandID = Int.min

        init(_ parent: SafetyMapKitView) { self.parent = parent }

        // Stable identity for a found place (its UUID churns across searches).
        private func key(_ p: FoundPlace) -> String {
            "\(p.name)@\(Int(p.coordinate.latitude * 1e4)),\(Int(p.coordinate.longitude * 1e4))"
        }

        func syncHeat(_ heat: HeatImage?, on map: MKMapView) {
            guard heatVersion != heat?.version else { return }
            heatVersion = heat?.version
            if let existing = heatOverlay { map.removeOverlay(existing); heatOverlay = nil }
            if let heat {
                let o = CrimeHeatOverlay(heat)
                heatOverlay = o
                map.addOverlay(o, level: .aboveRoads)
            }
        }

        func syncPlaces(_ places: [FoundPlace], on map: MKMapView) {
            var fresh: [String: FoundPlace] = [:]
            for p in places { fresh[key(p)] = p }
            // Remove pins that are gone; keep the rest in place (no flicker).
            for (k, ann) in placeAnnos where fresh[k] == nil {
                map.removeAnnotation(ann); placeAnnos[k] = nil
            }
            for (k, p) in fresh where placeAnnos[k] == nil {
                let a = PlaceAnnotation(place: p)
                placeAnnos[k] = a
                map.addAnnotation(a)
            }
        }

        func syncRoutes(_ routes: [MKRoute], selected: MKRoute?, danger: [MKRoute],
                        destination: CLLocationCoordinate2D?, name: String?, on map: MKMapView) {
            let newLines = routes.map(\.polyline)
            let dangerSet = Set(danger.map { ObjectIdentifier($0.polyline) })
            // Rebuild only when the route set actually changed (routes are rare).
            let changed = newLines.count != routeOverlays.count
                || zip(newLines, routeOverlays).contains { $0 !== $1 }
            if changed {
                map.removeOverlays(routeOverlays)
                routeOverlays = newLines
                selectedOverlay = selected?.polyline
                dangerOverlays = dangerSet
                if !newLines.isEmpty { map.addOverlays(newLines, level: .aboveRoads) }
            } else {
                // Selection / danger can flip without a geometry rebuild. Force the
                // renderers to redraw with the new colours.
                let prevSelected = selectedOverlay
                selectedOverlay = selected?.polyline
                if dangerOverlays != dangerSet || prevSelected !== selectedOverlay {
                    dangerOverlays = dangerSet
                    for line in routeOverlays {
                        if let r = map.renderer(for: line) as? MKPolylineRenderer {
                            style(r, for: line)
                        }
                    }
                }
            }

            // Destination flag.
            if let destination {
                if let d = destAnno {
                    if d.coordinate.latitude != destination.latitude
                        || d.coordinate.longitude != destination.longitude {
                        map.removeAnnotation(d)
                        let a = DestinationAnnotation(coordinate: destination, title: name)
                        destAnno = a; map.addAnnotation(a)
                    }
                } else {
                    let a = DestinationAnnotation(coordinate: destination, title: name)
                    destAnno = a; map.addAnnotation(a)
                }
            } else if let d = destAnno {
                map.removeAnnotation(d); destAnno = nil
            }
        }

        // MARK: Delegate

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let heat = overlay as? CrimeHeatOverlay {
                return CrimeHeatRenderer(heatOverlay: heat)
            }
            if let line = overlay as? MKPolyline {
                let r = MKPolylineRenderer(polyline: line)
                style(r, for: line)
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        /// Colour a route polyline: accent for the picked route, red for a
        /// danger route we steered around, muted grey for any other alternate.
        private func style(_ r: MKPolylineRenderer, for line: MKPolyline) {
            r.lineCap = .round
            r.lineJoin = .round
            if line === selectedOverlay {
                r.strokeColor = UIColor(Color.accentColor)
                r.lineWidth = 7
            } else if dangerOverlays.contains(ObjectIdentifier(line)) {
                r.strokeColor = UIColor.systemRed.withAlphaComponent(0.85)
                r.lineWidth = 5
            } else {
                r.strokeColor = UIColor.secondaryLabel.withAlphaComponent(0.5)
                r.lineWidth = 4
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            if let dest = annotation as? DestinationAnnotation {
                let id = "dest"
                let v = (mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView)
                    ?? MKMarkerAnnotationView(annotation: dest, reuseIdentifier: id)
                v.annotation = dest
                v.markerTintColor = UIColor(Color.accentColor)
                v.glyphImage = UIImage(systemName: "flag.fill")
                v.canShowCallout = true
                return v
            }
            if let place = annotation as? PlaceAnnotation {
                let id = "place"
                let v = (mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView)
                    ?? MKMarkerAnnotationView(annotation: place, reuseIdentifier: id)
                v.annotation = place
                v.markerTintColor = UIColor(place.place.category.tint)
                v.glyphImage = UIImage(systemName: place.place.category.symbol)
                v.canShowCallout = true
                v.displayPriority = .defaultLow   // let MapKit thin dense clusters
                return v
            }
            return nil
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.onRegionChange(mapView.region)
        }

        // MARK: Gestures

        @objc func handleLongPress(_ g: UILongPressGestureRecognizer) {
            guard g.state == .began, let map else { return }
            let coord = map.convert(g.location(in: map), toCoordinateFrom: map)
            parent.onLongPress(coord)
        }

        @objc func handleTap(_ g: UITapGestureRecognizer) {
            guard let map else { return }
            let pt = g.location(in: map)
            // Let pin taps fall through to MapKit's own selection / callout.
            if let hit = map.hitTest(pt, with: nil),
               (hit is MKAnnotationView || hit.superview is MKAnnotationView) { return }
            parent.onTap(map.convert(pt, toCoordinateFrom: map))
        }

        // Don't fight MapKit's own pan/zoom/tap recognizers.
        func gestureRecognizer(_ g: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
    }
}

private extension UIView {
    /// Every gesture recognizer on this view and its descendants. MapKit hangs
    /// its double-tap-to-zoom recognizer on an internal subview, not the map
    /// itself, so a flat `gestureRecognizers` read misses it.
    func allGestureRecognizers() -> [UIGestureRecognizer] {
        (gestureRecognizers ?? []) + subviews.flatMap { $0.allGestureRecognizers() }
    }
}

/// A nearby-service pin carrying its found place (for glyph + tint + callout).
final class PlaceAnnotation: NSObject, MKAnnotation {
    let place: FoundPlace
    var coordinate: CLLocationCoordinate2D { place.coordinate }
    var title: String? { place.name }
    var subtitle: String? { place.category.title }
    init(place: FoundPlace) { self.place = place }
}

/// The route destination flag.
final class DestinationAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    init(coordinate: CLLocationCoordinate2D, title: String?) {
        self.coordinate = coordinate
        self.title = title ?? "Destination"
    }
}

import SwiftUI
import MapKit
import iUXiOS

/// The interactive safety map — the heart of Aware. Shows the user's position,
/// a filter row of nearby-service categories, and a crime-heatmap toggle. The
/// actual POI search + heatmap data source are wired in a later pass; this
/// scaffold lays out the chrome and the live `Map`.
struct SafetyMapView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(RoutePlanner.self) private var planner

    @State private var camera: MapCameraPosition = .automatic
    @State private var selected: Set<ServiceCategory> = [.police, .hospital]
    @State private var search = PlaceSearch()
    @State private var crime = CrimeService()
    @State private var region: MKCoordinateRegion?
    @State private var heat: [HeatCell] = []

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            MapReader { proxy in
            Map(position: $camera) {
                UserAnnotation()

                if settings.showCrimeHeatmap {
                    // Crime aggregated into a zoom-scaled grid: one disc per cell,
                    // coloured by how its count compares to the busiest cell in
                    // view (faint amber → solid red). Hotspots pop; quiet areas
                    // stay see-through; far fewer overlays than one-disc-per-crime.
                    ForEach(heat) { cell in
                        MapCircle(center: cell.coordinate, radius: cell.radius)
                            .foregroundStyle(Self.heatColor(cell.intensity))
                            .mapOverlayLevel(level: .aboveRoads)
                    }
                }

                ForEach(search.places) { place in
                    Marker(place.name, systemImage: place.category.symbol,
                           coordinate: place.coordinate)
                        .tint(place.category.tint)
                }

                // Computed routes: alternates faint, the chosen one bold accent.
                ForEach(Array(planner.routes.enumerated()), id: \.offset) { _, r in
                    let isSel = r == planner.selected
                    MapPolyline(r.polyline)
                        .stroke(isSel ? Color.accentColor : .secondary.opacity(0.5),
                                style: StrokeStyle(lineWidth: isSel ? 7 : 4,
                                                   lineCap: .round, lineJoin: .round))
                }
                if let dest = planner.destination {
                    Marker(planner.destinationName ?? "Destination",
                           systemImage: "flag.fill", coordinate: dest)
                        .tint(Color.accentColor)
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .ignoresSafeArea(edges: .bottom)
            // Long-press anywhere on the map → route there. The sequenced
            // drag reads the touch location so we can convert it to a coordinate.
            .gesture(
                LongPressGesture(minimumDuration: 0.4)
                    .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
                    .onEnded { value in
                        if case .second(true, let drag?) = value,
                           let coord = proxy.convert(drag.location, from: .local) {
                            routeTo(coord)
                        }
                    }
            )
            .safeAreaInset(edge: .top) { categoryBar }
            .safeAreaInset(edge: .bottom) { heatmapToggle }
            .onMapCameraChange(frequency: .onEnd) { ctx in
                region = ctx.region
                Task { await runSearch() }
                if settings.showCrimeHeatmap {
                    rebuildHeat()   // re-grid at the new zoom
                    Task { await crime.load(region: ctx.region) }
                }
            }
            .task(id: selected) { await runSearch() }
            .task(id: settings.showCrimeHeatmap) {
                if settings.showCrimeHeatmap, let region {
                    await crime.load(region: region)
                }
            }
            .overlay(alignment: .top) {
                if search.isSearching || crime.isLoading {
                    ProgressView().padding(.top, 60)
                }
            }
            .overlay(alignment: .bottomLeading) {
                if settings.showCrimeHeatmap {
                    Text(crime.sourceName.map { "Crime data: \($0)" }
                         ?? "No crime data for this area")
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .glassPill()
                        .padding(.leading, UX.screenPadding)
                        .padding(.bottom, 70)
                }
            }
            .overlay(alignment: .bottom) {
                if planner.destination != nil {
                    routeCard.padding(.bottom, 70)
                }
            }
            .task(id: settings.preferSaferRoutes) {
                planner.choose(preferSafer: settings.preferSaferRoutes, crime: crime.points)
            }
            // Re-grid the heatmap + re-pick the safer route whenever fresh crime
            // data lands.
            .task(id: crimeSignature) {
                rebuildHeat()
                if !planner.routes.isEmpty {
                    planner.choose(preferSafer: settings.preferSaferRoutes, crime: crime.points)
                }
            }
            // A route arrived (e.g. handed off from the Routes tab) with no crime
            // data yet — fetch it for the destination area even if the heatmap is
            // off, so "safer" still means something, then re-pick.
            .task(id: routeSignature) {
                if !planner.routes.isEmpty, settings.preferSaferRoutes,
                   crime.points.isEmpty, let dest = planner.destination {
                    await crime.load(region: MKCoordinateRegion(
                        center: dest, latitudinalMeters: 2_000, longitudinalMeters: 2_000))
                    planner.choose(preferSafer: settings.preferSaferRoutes, crime: crime.points)
                }
            }
            .navigationTitle("Aware")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        model.location.requestOneShot()
                        camera = .userLocation(fallback: .automatic)
                    } label: {
                        Image(systemName: "location.fill")
                    }
                }
            }
            } // MapReader
        }
    }

    /// Aggregate crime points into a zoom-scaled grid. One disc per occupied
    /// cell, intensity = cell count vs the busiest cell in view. Cheap, and reads
    /// as a real heatmap instead of a flat red wall.
    private func rebuildHeat() {
        guard let region, !crime.points.isEmpty else { heat = []; return }
        // ~22 cells across the longer visible axis, so the grid tracks zoom.
        let cellDeg = max(region.span.latitudeDelta, region.span.longitudeDelta) / 22
        guard cellDeg > 0 else { heat = []; return }

        var buckets: [GridKey: Int] = [:]
        for p in crime.points {
            let key = GridKey(x: Int((p.coordinate.latitude / cellDeg).rounded(.down)),
                              y: Int((p.coordinate.longitude / cellDeg).rounded(.down)))
            buckets[key, default: 0] += 1
        }
        let maxCount = max(buckets.values.max() ?? 1, 1)
        let radius = cellDeg * 111_000 * 0.62   // slight overlap smooths the field
        heat = buckets.map { key, count in
            HeatCell(coordinate: CLLocationCoordinate2D(latitude: (Double(key.x) + 0.5) * cellDeg,
                                                        longitude: (Double(key.y) + 0.5) * cellDeg),
                     intensity: min(1, Double(count) / Double(maxCount)),
                     radius: radius)
        }
    }

    /// Amber (quiet) → red (hotspot), opacity rising with intensity. Capped below
    /// fully opaque so street labels still read through the busiest cells.
    static func heatColor(_ t: Double) -> Color {
        Color(hue: (1 - t) * 0.13, saturation: 0.9, brightness: 1.0)
            .opacity(0.20 + 0.32 * t)
    }

    /// Changes when the loaded crime set changes — drives the safer-route re-pick.
    private var crimeSignature: String { "\(crime.sourceName ?? "")#\(crime.points.count)" }
    /// Changes when a new route is computed.
    private var routeSignature: String {
        "\(planner.routes.count)#\(planner.destination?.latitude ?? 0)"
    }

    /// Long-press handler: route from the user's current location to `coord`.
    private func routeTo(_ coord: CLLocationCoordinate2D) {
        guard let from = model.location.location?.coordinate else {
            model.location.requestOneShot()
            return
        }
        Task {
            await planner.route(from: from, to: coord, name: nil,
                                preferSafer: settings.preferSaferRoutes, crime: crime.points)
            // Frame the route.
            if let dest = planner.destination {
                let mid = CLLocationCoordinate2D(latitude: (from.latitude + dest.latitude) / 2,
                                                 longitude: (from.longitude + dest.longitude) / 2)
                let span = MKCoordinateSpan(
                    latitudeDelta: abs(from.latitude - dest.latitude) * 1.8 + 0.01,
                    longitudeDelta: abs(from.longitude - dest.longitude) * 1.8 + 0.01)
                withAnimation { camera = .region(MKCoordinateRegion(center: mid, span: span)) }
            }
        }
    }

    @ViewBuilder private var routeCard: some View {
        VStack(spacing: 8) {
            if planner.isRouting {
                HStack(spacing: 8) { ProgressView(); Text("Finding safer route…") }
                    .font(.subheadline)
            } else if let route = planner.selected {
                HStack(spacing: 12) {
                    Image(systemName: "figure.walk")
                        .font(.title3).foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(routeSummary(route)).font(.headline)
                        if let reason = planner.reason {
                            Text(reason).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button {
                        planner.clear()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2).foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            } else if let err = planner.errorText {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text(err).font(.subheadline)
                    Spacer()
                    Button("Dismiss") { planner.clear() }.font(.subheadline)
                }
            }
        }
        .padding(14)
        .glassCard(shadow: true)
        .padding(.horizontal, UX.screenPadding)
    }

    private func routeSummary(_ route: MKRoute) -> String {
        let mins = Int((route.expectedTravelTime / 60).rounded())
        let dist = Measurement(value: route.distance, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road))
        return "\(mins) min walk · \(dist)"
    }

    /// Search the visible region for the toggled-on service categories. Driven by
    /// camera settle + selection change; the place search cancels any in-flight
    /// request so only the latest region's results stick.
    private func runSearch() async {
        guard let region else { return }
        // Convert the visible latitude span to a metres radius for the POI query.
        let radius = region.span.latitudeDelta * 111_000 / 2
        await search.search(categories: selected, center: region.center, radius: radius)
    }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ServiceCategory.allCases) { cat in
                    let on = selected.contains(cat)
                    Button {
                        if on { selected.remove(cat) } else { selected.insert(cat) }
                    } label: {
                        Label(cat.title, systemImage: cat.symbol)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(on ? .white : .primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background {
                                Capsule()
                                    .fill(on ? AnyShapeStyle(cat.tint) : AnyShapeStyle(.regularMaterial))
                            }
                            .overlay {
                                Capsule()
                                    .strokeBorder(on ? .white.opacity(0.5) : cat.tint.opacity(0.9),
                                                  lineWidth: 1.5)
                            }
                            .shadow(color: .black.opacity(0.35), radius: 5, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, UX.screenPadding)
            .padding(.vertical, 8)
        }
    }

    private var heatmapToggle: some View {
        let on = settings.showCrimeHeatmap
        return Button {
            settings.showCrimeHeatmap.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                Text("Crime heatmap")
                    .fontWeight(.semibold)
                Text(on ? "ON" : "OFF")
                    .font(.caption2.weight(.heavy))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(on ? .white.opacity(0.25) : .secondary.opacity(0.25)))
            }
            .font(.subheadline)
            .foregroundStyle(on ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background {
                Capsule()
                    .fill(on ? AnyShapeStyle(Color.red) : AnyShapeStyle(.regularMaterial))
            }
            .overlay {
                Capsule()
                    .strokeBorder(on ? .white.opacity(0.5) : .red.opacity(0.9), lineWidth: 1.5)
            }
            .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 8)
    }
}

/// One aggregated heatmap cell.
private struct HeatCell: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let intensity: Double      // 0…1 relative to the busiest visible cell
    let radius: CLLocationDistance
}

/// Integer grid coordinate used to bucket crimes during aggregation.
private struct GridKey: Hashable { let x: Int; let y: Int }

/// Nearby-service categories surfaced on the safety map. Mirrors the proposal's
/// list of "explore nearby" places.
enum ServiceCategory: String, CaseIterable, Identifiable {
    case police, hospital, fireStation, pharmacy, transport, taxi, open24h

    var id: String { rawValue }

    var title: String {
        switch self {
        case .police:      return "Police"
        case .hospital:    return "Hospital"
        case .fireStation: return "Fire"
        case .pharmacy:    return "Pharmacy"
        case .transport:   return "Transport"
        case .taxi:        return "Taxi"
        case .open24h:     return "24-hour"
        }
    }

    var symbol: String {
        switch self {
        case .police:      return "shield.lefthalf.filled"
        case .hospital:    return "cross.fill"
        case .fireStation: return "flame.fill"
        case .pharmacy:    return "pills.fill"
        case .transport:   return "tram.fill"
        case .taxi:        return "car.fill"
        case .open24h:     return "clock.fill"
        }
    }

    var tint: Color {
        switch self {
        case .police:      return .blue
        case .hospital:    return .red
        case .fireStation: return .orange
        case .pharmacy:    return .green
        case .transport:   return .teal
        case .taxi:        return .yellow
        case .open24h:     return .purple
        }
    }

    /// MapKit POI categories this filter maps to for live search. `nil` means
    /// there's no first-class POI category (taxi, generic 24-hour) — those are
    /// skipped by the points-of-interest search for now.
    var poiCategories: [MKPointOfInterestCategory] {
        switch self {
        case .police:      return [.police]
        case .hospital:    return [.hospital]
        case .fireStation: return [.fireStation]
        case .pharmacy:    return [.pharmacy]
        case .transport:   return [.publicTransport]
        case .taxi:        return []
        case .open24h:     return []
        }
    }

    /// Reverse-map a found POI back to the category that surfaced it, so a result
    /// pin gets the right tint and glyph.
    static func from(_ poi: MKPointOfInterestCategory?) -> ServiceCategory? {
        guard let poi else { return nil }
        return allCases.first { $0.poiCategories.contains(poi) }
    }
}

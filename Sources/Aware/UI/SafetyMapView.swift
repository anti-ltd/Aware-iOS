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

    @State private var selected: Set<ServiceCategory> = [.police, .hospital]
    @State private var search = PlaceSearch()
    @State private var crime = CrimeService()
    @State private var region: MKCoordinateRegion?
    /// The rendered crime heat raster (nil when the heatmap is off or empty).
    @State private var heatImage: HeatImage?
    @State private var heatVersion = 0
    /// The region the heat raster + POI search were last rebuilt for. Used to skip
    /// the re-render/re-search churn on tiny camera settles (mirrors the gate in
    /// `CrimeService.load`).
    @State private var lastGridRegion: MKCoordinateRegion?
    /// Imperative camera moves (recenter, frame a route) + their monotonic id.
    @State private var mapCommand: MapCommand?
    @State private var commandSeq = 0
    /// Tapped-area crime detail (drives the insights sheet).
    @State private var insight: AreaInsight?

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            SafetyMapKitView(
                heat: settings.showCrimeHeatmap ? heatImage : nil,
                places: search.places,
                routes: planner.routes,
                selectedRoute: planner.selected,
                dangerRoutes: planner.dangerRoutes(),
                destination: planner.destination,
                destinationName: planner.destinationName,
                showsUserLocation: true,
                command: mapCommand,
                onRegionChange: handleRegionChange,
                onLongPress: routeTo,
                onTap: showInsights)
            // Fill the whole screen so the nav bar + filter chips float over the
            // map as translucent glass (SwiftUI Map did this implicitly; the
            // MKMapView bridge needs it spelled out).
            .ignoresSafeArea()
            .safeAreaInset(edge: .top) { categoryBar }
            .safeAreaInset(edge: .bottom) { bottomControls }
            .task(id: selected) { await runSearch() }
            .task(id: settings.showCrimeHeatmap) {
                if settings.showCrimeHeatmap {
                    if let region { await crime.load(region: region) }
                    rebuildHeatImage()
                } else {
                    heatImage = nil
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
                rebuildHeatImage()
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
                        if let loc = model.location.location?.coordinate {
                            moveCamera(to: MKCoordinateRegion(center: loc,
                                latitudinalMeters: 1_500, longitudinalMeters: 1_500))
                        }
                    } label: {
                        Image(systemName: "location.fill")
                    }
                }
            }
            .sheet(item: $insight) { item in
                AreaInsightSheet(insight: item) { routeTo($0) }
            }
            .onAppear { model.location.requestOneShot() }
        }
    }

    /// Re-render the crime heat raster for the current region + loaded crime set.
    /// Cheap (low-res KDE, gated to camera settles) and produces a real smooth
    /// heat field via `CrimeHeat.render`, not a grid of discs.
    private func rebuildHeatImage() {
        guard settings.showCrimeHeatmap, let region else { heatImage = nil; return }
        heatVersion += 1
        heatImage = CrimeHeat.render(points: crime.points, region: region, version: heatVersion)
    }

    /// Camera-settle handler from the map view. Reports the region, then — gated
    /// to skip micro-settles — re-runs the POI search, re-renders the heat, and
    /// refetches crime for the new viewport.
    private func handleRegionChange(_ r: MKCoordinateRegion) {
        region = r
        guard Self.regionMovedEnough(from: lastGridRegion, to: r) else { return }
        lastGridRegion = r
        Task { await runSearch() }
        if settings.showCrimeHeatmap {
            rebuildHeatImage()
            Task { await crime.load(region: r) }
        }
    }

    /// Issue an imperative camera move (recenter / frame a route).
    private func moveCamera(to region: MKCoordinateRegion) {
        commandSeq += 1
        mapCommand = MapCommand(region: region, id: commandSeq)
    }

    /// Tap-on-map handler: summarise reported crime around the tapped point into
    /// the insights sheet. Radius scales with zoom (a slice of the view height).
    private func showInsights(_ coord: CLLocationCoordinate2D) {
        guard !crime.points.isEmpty else { return }
        let viewMeters = (region?.span.latitudeDelta ?? 0.05) * 111_000
        let radius = min(1_500, max(150, viewMeters * 0.12))
        let here = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        let near = crime.points.filter {
            here.distance(from: CLLocation(latitude: $0.coordinate.latitude,
                                           longitude: $0.coordinate.longitude)) <= radius
        }
        var counts: [String: Int] = [:]
        for c in near { counts[Self.prettyCategory(c.category), default: 0] += 1 }
        let breakdown = counts.sorted { $0.value > $1.value }
            .map { CategoryCount(name: $0.key, count: $0.value) }
        insight = AreaInsight(coordinate: coord, radiusMeters: radius,
                              total: near.count, breakdown: breakdown,
                              source: crime.sourceName)
    }

    /// Humanise a raw provider category code ("anti-social-behaviour" → "Anti
    /// Social Behaviour").
    private static func prettyCategory(_ raw: String) -> String {
        raw.replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    /// True if the camera moved/zoomed enough to be worth re-searching + re-gridding
    /// — mirrors `CrimeService.load`'s 500 m / 25 %-span gate so a settle that
    /// skips the fetch also skips the (otherwise pointless) re-grid.
    private static func regionMovedEnough(from last: MKCoordinateRegion?, to now: MKCoordinateRegion) -> Bool {
        guard let last else { return true }
        let moved = CLLocation(latitude: last.center.latitude, longitude: last.center.longitude)
            .distance(from: CLLocation(latitude: now.center.latitude, longitude: now.center.longitude))
        let zoomed = abs(last.span.latitudeDelta - now.span.latitudeDelta) >= now.span.latitudeDelta * 0.25
        return moved >= 500 || zoomed
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
                moveCamera(to: MKCoordinateRegion(center: mid, span: span))
            }
        }
    }

    @ViewBuilder private var routeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if planner.isRouting {
                HStack(spacing: 8) { ProgressView(); Text("Finding safer route…") }
                    .font(.subheadline)
            } else if !planner.routes.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "figure.walk").font(.title3).foregroundStyle(.tint)
                    Text(planner.routes.count > 1 ? "Walking routes" : "Walking route")
                        .font(.headline)
                    Spacer()
                    Button { planner.clear() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2).foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                // One row per route, each with its safety rating; tap to pick.
                ForEach(Array(planner.routes.enumerated()), id: \.offset) { _, route in
                    routeRow(route)
                }
                if let reason = planner.reason {
                    Text(reason).font(.caption).foregroundStyle(.secondary)
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

    /// A single selectable route row: pick indicator, time/distance, safety badge.
    private func routeRow(_ route: MKRoute) -> some View {
        let isSelected = route === planner.selected
        let rating = planner.rating(for: route, crime: crime.points)
        return Button {
            planner.select(route)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.body)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                Text(routeSummary(route))
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                Spacer()
                SafetyBadge(rating: rating)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Safety rating for the ring around the user's current location, or nil when
    /// we don't have a fix or any crime data to judge by.
    private var myAreaRating: SafetyRating? {
        guard let loc = model.location.location?.coordinate, !crime.points.isEmpty else { return nil }
        let here = CLLocation(latitude: loc.latitude, longitude: loc.longitude)
        let radius = 400.0
        let n = crime.points.filter {
            here.distance(from: CLLocation(latitude: $0.coordinate.latitude,
                                           longitude: $0.coordinate.longitude)) <= radius
        }.count
        return .forArea(crimeCount: n)
    }

    /// Bottom control row: the heatmap toggle and the current-area safety rating
    /// sit on the same line.
    private var bottomControls: some View {
        HStack(spacing: 8) {
            heatmapToggle
            areaRatingButton
        }
        .padding(.bottom, 8)
    }

    /// Current-area safety rating as a pill, styled to match the heatmap toggle.
    /// Tapping it opens the insights sheet centred on the user's location.
    @ViewBuilder private var areaRatingButton: some View {
        if let rating = myAreaRating, let loc = model.location.location?.coordinate {
            Button {
                showInsights(loc)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: rating.symbol)
                    Text("Your area").fontWeight(.semibold)
                    Text(rating.label).fontWeight(.bold)
                }
                .font(.subheadline)
                .foregroundStyle(rating.color)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background { Capsule().fill(.regularMaterial) }
                .overlay { Capsule().strokeBorder(rating.color.opacity(0.8), lineWidth: 1.5) }
                .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
        }
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
    }
}

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

import SwiftUI
import MapKit
import iUXiOS

/// Safer route planning. The user picks a destination and Aware ranks routes by
/// safety factors (crime density, lighting, population, service proximity, time
/// of day) rather than speed alone. This scaffold lays out the inputs and the
/// safety-factor weighting; the routing engine is a later pass.
struct RoutesView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(AppModel.self) private var model
    @Environment(RoutePlanner.self) private var planner

    @State private var destination = ""
    @State private var searching = false
    @State private var notFound = false
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            ScrollView {
                VStack(spacing: UX.cardSpacing) {
                    CardSection("Plan a safer route") {
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.secondary)
                                TextField("Where to?", text: $destination)
                                    .textFieldStyle(.plain)
                                    .focused($focused)
                                    .submitLabel(.search)
                            }
                            .padding(12)
                            .glassPill()

                            Button {
                                focused = false
                                Task { await findRoute() }
                            } label: {
                                Label(searching ? "Searching…" : "Find safer routes",
                                      systemImage: "shield.checkered")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                            .glassPill(tint: .accentColor)
                            .foregroundStyle(.tint)
                            .disabled(destination.isEmpty || searching)
                            .opacity(destination.isEmpty ? 0.5 : 1)
                        }
                    }

                    CardSection("Safety factors") {
                        VStack(spacing: 0) {
                            ToggleRow("Prefer safer routes",
                                      subtitle: "Weight by crime, lighting and service proximity",
                                      isOn: $settings.preferSaferRoutes)
                            ForEach(SafetyFactor.allCases) { factor in
                                Divider().opacity(0.4)
                                HStack {
                                    Label(factor.title, systemImage: factor.symbol)
                                    Spacer()
                                    Image(systemName: settings.preferSaferRoutes
                                          ? "checkmark.circle.fill" : "minus.circle")
                                        .foregroundStyle(settings.preferSaferRoutes ? .green : .secondary)
                                }
                                .font(.subheadline)
                                .padding(.vertical, UX.rowVPadding)
                            }
                        }
                    }

                    EmptyStateCard(
                        symbol: "map.circle",
                        title: "No route yet",
                        message: "Enter a destination above to compare routes by how safe they are, not just how fast.")
                }
                .padding(UX.screenPadding)
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .ambientBackground(tint: .accentColor)
            .navigationTitle("Routes")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focused = false }
                }
            }
            .alert("Couldn't find that place", isPresented: $notFound) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Try a more specific name or address.")
            }
        }
    }

    /// Geocode the typed destination near the user, compute a route, then jump to
    /// the Map tab where the route is drawn.
    private func findRoute() async {
        guard let from = model.location.location?.coordinate else {
            model.location.requestOneShot()
            notFound = true   // no fix yet — nudge the user
            return
        }
        searching = true
        defer { searching = false }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = destination
        request.region = MKCoordinateRegion(center: from,
                                            latitudinalMeters: 30_000, longitudinalMeters: 30_000)
        guard let item = try? await MKLocalSearch(request: request).start().mapItems.first else {
            notFound = true
            return
        }
        await planner.route(from: from, to: item.placemark.coordinate,
                            name: item.name,
                            preferSafer: settings.preferSaferRoutes, crime: [])
        model.selectedTab = .map
    }
}

private enum SafetyFactor: String, CaseIterable, Identifiable {
    case crime, lighting, population, services, timeOfDay

    var id: String { rawValue }

    var title: String {
        switch self {
        case .crime:      return "Crime density"
        case .lighting:   return "Lighting availability"
        case .population: return "Population density"
        case .services:   return "Emergency-service proximity"
        case .timeOfDay:  return "Time of day"
        }
    }

    var symbol: String {
        switch self {
        case .crime:      return "exclamationmark.triangle.fill"
        case .lighting:   return "lightbulb.fill"
        case .population: return "person.3.fill"
        case .services:   return "cross.case.fill"
        case .timeOfDay:  return "clock.fill"
        }
    }
}

/**
 Merges anti.ltd `/status` with on-device services for Settings → Service status.
 */
import Foundation
import SwiftUI

enum ServiceStatusCatalog {
    enum Availability: String, Codable, Sendable {
        case live, gated, unconfigured, regional, partial

        var label: String {
            switch self {
            case .live:          "Live"
            case .regional:      "Regional"
            case .gated, .unconfigured, .partial: "Down"
            }
        }

        var tint: Color {
            switch self {
            case .live:          .green
            case .regional:      .cyan
            case .gated, .unconfigured, .partial: .secondary
            }
        }

        var symbol: String {
            switch self {
            case .live:          "checkmark.circle.fill"
            case .regional:      "globe.americas.fill"
            case .gated, .unconfigured, .partial: "xmark.circle.fill"
            }
        }

        var isDown: Bool {
            switch self {
            case .gated, .unconfigured, .partial: true
            case .live, .regional: false
            }
        }
    }

    struct Item: Identifiable, Sendable {
        let id: String
        let title: String
        let symbol: String
        let relay: String
        let availability: Availability
        let detail: String
        let regions: [String]?

        var displayDetail: String {
            availability.isDown ? "Down" : detail
        }

        var viaAntiLtd: Bool { relay == "anti.ltd" }
    }

    struct Group: Identifiable, Sendable {
        let id: String
        let title: String
        let items: [Item]
    }

    struct Snapshot: Sendable {
        let catalogVersion: String
        let generatedAt: Date?
        let relayHealthy: Bool
        let apiKeyState: TrackingAPI.ApiKeyState
        let groups: [Group]
        let isRemote: Bool

        var relayReachable: Bool {
            relayHealthy && apiKeyState == .valid
        }

        var summaryLine: String {
            let items = groups.flatMap(\.items)
            let live = items.filter { $0.availability == .live }.count
            let down = items.filter(\.availability.isDown).count
            if apiKeyState == .missing { return "API key not configured" }
            if apiKeyState == .invalid { return "API key rejected" }
            if down > 0 { return "\(live) live · \(down) down" }
            return "\(live) of \(items.count) live"
        }
    }

    static func load(force: Bool = false) async -> Snapshot {
        let result = await TrackingCatalogStore.refreshStatus(force: force)
        if let payload = result.payload {
            return merge(payload, isRemote: result.fetchedLive, apiKeyState: result.apiKeyState)
        }
        return merge(bundledPayload(), isRemote: false, apiKeyState: result.apiKeyState)
    }

    private static func merge(
        _ payload: TrackingCatalogStore.StatusPayload,
        isRemote: Bool,
        apiKeyState: TrackingAPI.ApiKeyState
    ) -> Snapshot {
        var groups = [mapsGroup]
        if let crime = payload.groups.first(where: { $0.id == "local" }) {
            groups.append(Group(
                id: "crime",
                title: "Crime heatmap",
                items: crime.items.map(mapItem)))
        }
        return Snapshot(
            catalogVersion: payload.catalogVersion,
            generatedAt: ISO8601DateFormatter().date(from: payload.generatedAt),
            relayHealthy: payload.relay.healthy,
            apiKeyState: apiKeyState,
            groups: groups,
            isRemote: isRemote)
    }

    private static let mapsGroup = Group(
        id: "maps",
        title: "Maps & routes",
        items: [
            .init(id: "mapkit-tiles", title: "Map tiles & places", symbol: "map.fill", relay: "device",
                  availability: .live, detail: "Apple Maps on your phone.", regions: ["global"]),
            .init(id: "mapkit-directions", title: "Safer-route directions", symbol: "figure.walk", relay: "device",
                  availability: .live, detail: "Walking routes with optional crime weighting.", regions: ["global"]),
        ])

    private static func mapItem(_ item: TrackingCatalogStore.StatusPayload.StatusItem) -> Item {
        let availability = Availability(rawValue: item.availability) ?? .live
        return Item(
            id: item.id,
            title: item.title,
            symbol: item.symbol,
            relay: item.relay,
            availability: availability,
            detail: sanitize(item.detail),
            regions: item.regions)
    }

    private static func sanitize(_ text: String) -> String {
        text
            .replacingOccurrences(of: " — ", with: ". ")
            .replacingOccurrences(of: " – ", with: ". ")
            .replacingOccurrences(of: "—", with: ". ")
            .replacingOccurrences(of: "–", with: ". ")
            .replacingOccurrences(of: "..", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func bundledPayload() -> TrackingCatalogStore.StatusPayload {
        TrackingCatalogStore.StatusPayload(
            catalogVersion: "offline",
            generatedAt: "",
            relay: .init(healthy: true, configured: .init(
                aishub: false, blitzortung: false, firms: false,
                rapidapi: false, ukTrains: false, apns: false)),
            groups: [
                .init(id: "local", title: "Local", items: [
                    .init(id: "events", title: "Crime heat", symbol: "shield.fill", relay: "anti.ltd",
                          availability: "regional",
                          detail: "UK police data, US metros, and international cities with street-level feeds.",
                          filterable: true, regions: ["uk", "us", "ca"]),
                ]),
            ])
    }
}

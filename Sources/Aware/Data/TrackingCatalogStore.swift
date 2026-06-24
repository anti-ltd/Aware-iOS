/**
 Fetches and caches the anti.ltd sources + crime coverage catalogs for Settings UI.
 */
import Foundation

enum TrackingCatalogStore {
    struct SourcesPayload: Codable {
        let catalogVersion: String
        let groups: [Group]

        struct Group: Codable, Identifiable {
            let id: String
            let title: String
            let sources: [Source]
        }

        struct Source: Codable, Identifiable {
            let id: String
            let name: String
            let detail: String
            let url: String
            let cadence: String
            let nerd: String?
            let relay: String
            let upstream: String?
            let regions: [String]?
        }
    }

    struct CoverageIndexPayload: Codable {
        let catalogVersion: String
        let groups: [Group]

        struct Group: Codable {
            let id: String
            let title: String
            let layers: [Layer]
        }

        struct Layer: Codable, Identifiable {
            let id: String
            let title: String
            let summary: String
            let footprintKind: String
            let relay: String
        }
    }

    struct CoverageLayerPayload: Codable {
        let layer: String
        let catalogVersion: String
        let footprintKind: String
        let summary: String
        let relay: String
        let regions: [Region]

        struct Region: Codable, Identifiable {
            let id: String
            let label: String
            let ring: [[Double]]
        }
    }

    private actor Cache {
        static let shared = Cache()

        private let sourcesKey = "tracking-sources.v1"
        private let coverageIndexKey = "tracking-coverage-index.v1"
        private let coverageLayerPrefix = "tracking-coverage-layer.v1."

        private var cachedSources: SourcesPayload?
        private var cachedCoverageIndex: CoverageIndexPayload?
        private var cachedLayers: [String: CoverageLayerPayload] = [:]

        func sources() -> SourcesPayload? {
            if let cachedSources { return cachedSources }
            guard let data = UserDefaults.standard.data(forKey: sourcesKey),
                  let decoded = try? JSONDecoder().decode(SourcesPayload.self, from: data) else { return nil }
            cachedSources = decoded
            return decoded
        }

        func coverageIndex() -> CoverageIndexPayload? {
            if let cachedCoverageIndex { return cachedCoverageIndex }
            guard let data = UserDefaults.standard.data(forKey: coverageIndexKey),
                  let decoded = try? JSONDecoder().decode(CoverageIndexPayload.self, from: data) else { return nil }
            cachedCoverageIndex = decoded
            return decoded
        }

        func coverageLayer(_ layerId: String) -> CoverageLayerPayload? {
            if let hit = cachedLayers[layerId] { return hit }
            let key = coverageLayerPrefix + layerId
            guard let data = UserDefaults.standard.data(forKey: key),
                  let decoded = try? JSONDecoder().decode(CoverageLayerPayload.self, from: data) else { return nil }
            cachedLayers[layerId] = decoded
            return decoded
        }

        func refreshIfNeeded() async {
            await refreshSources()
            await refreshCoverageIndex()
        }

        func loadCoverageLayer(_ layerId: String) async {
            if cachedLayers[layerId] != nil { return }
            if coverageLayer(layerId) != nil { return }
            guard let url = TrackingAPI.url(path: "coverage/\(layerId)") else { return }
            guard let (data, resp) = try? await URLSession.shared.data(from: url),
                  (resp as? HTTPURLResponse)?.statusCode == 200,
                  let payload = try? JSONDecoder().decode(CoverageLayerPayload.self, from: data) else { return }
            cachedLayers[layerId] = payload
            UserDefaults.standard.set(data, forKey: coverageLayerPrefix + layerId)
        }

        private func refreshSources() async {
            guard let url = TrackingAPI.url(path: "sources") else { return }
            var req = URLRequest(url: url)
            if let etag = UserDefaults.standard.string(forKey: sourcesKey + ".etag") {
                req.setValue(etag, forHTTPHeaderField: "If-None-Match")
            }
            guard let (data, resp) = try? await URLSession.shared.data(for: req) else { return }
            guard let http = resp as? HTTPURLResponse else { return }
            if http.statusCode == 304 { _ = sources(); return }
            guard http.statusCode == 200,
                  let payload = try? JSONDecoder().decode(SourcesPayload.self, from: data) else { return }
            cachedSources = payload
            UserDefaults.standard.set(data, forKey: sourcesKey)
            if let etag = http.value(forHTTPHeaderField: "ETag") {
                UserDefaults.standard.set(etag, forKey: sourcesKey + ".etag")
            }
        }

        private func refreshCoverageIndex() async {
            guard let url = TrackingAPI.url(path: "coverage") else { return }
            guard let (data, resp) = try? await URLSession.shared.data(from: url),
                  (resp as? HTTPURLResponse)?.statusCode == 200,
                  let payload = try? JSONDecoder().decode(CoverageIndexPayload.self, from: data) else { return }
            cachedCoverageIndex = payload
            UserDefaults.standard.set(data, forKey: coverageIndexKey)
        }
    }

    static func sources() async -> SourcesPayload? {
        await Cache.shared.sources()
    }

    static func coverageIndex() async -> CoverageIndexPayload? {
        await Cache.shared.coverageIndex()
    }

    static func coverageLayer(_ layerId: String) async -> CoverageLayerPayload? {
        await Cache.shared.coverageLayer(layerId)
    }

    static func refreshIfNeeded() async {
        await Cache.shared.refreshIfNeeded()
    }

    static func loadCoverageLayer(_ layerId: String) async {
        await Cache.shared.loadCoverageLayer(layerId)
    }
}

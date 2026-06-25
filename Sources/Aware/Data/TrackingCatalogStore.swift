/**
 Fetches and caches the anti.ltd sources + crime coverage catalogs for Settings UI.
 */
import Foundation

enum TrackingCatalogStore {
    struct StatusRefreshResult: Sendable {
        let payload: StatusPayload?
        let apiKeyState: TrackingAPI.ApiKeyState
        let fetchedLive: Bool
    }

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
        let regionGroups: [CountryGroup]?

        struct Region: Codable, Identifiable {
            let id: String
            let label: String
            let ring: [[Double]]
        }

        struct RegionRef: Codable, Identifiable, Hashable {
            let id: String
            let label: String
            let kind: String?
        }

        struct AdminGroup: Codable, Identifiable, Hashable {
            let id: String
            let label: String
            let regions: [RegionRef]
        }

        struct CountryGroup: Codable, Identifiable, Hashable {
            let id: String
            let label: String
            let regions: [RegionRef]
            let adminAreas: [AdminGroup]?
        }
    }

    struct StatusPayload: Codable {
        let catalogVersion: String
        let generatedAt: String
        let relay: Relay
        let groups: [Group]

        struct Relay: Codable {
            let healthy: Bool
            let configured: RelayConfig
        }

        struct RelayConfig: Codable {
            let aishub: Bool
            let blitzortung: Bool
            let firms: Bool
            let rapidapi: Bool
            let ukTrains: Bool
            let apns: Bool
        }

        struct Group: Codable, Identifiable {
            let id: String
            let title: String
            let items: [StatusItem]
        }

        struct StatusItem: Codable, Identifiable {
            let id: String
            let title: String
            let symbol: String
            let relay: String
            let availability: String
            let detail: String
            let filterable: Bool
            let regions: [String]?
        }
    }

    private actor Cache {
        static let shared = Cache()

        private let sourcesKey = "tracking-sources.v1"
        private let coverageIndexKey = "tracking-coverage-index.v2"
        private let statusKey = "tracking-status.v2"
        private let coverageLayerPrefix = "tracking-coverage-layer.v2."

        private var cachedSources: SourcesPayload?
        private var cachedCoverageIndex: CoverageIndexPayload?
        private var cachedStatus: StatusPayload?
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
            _ = await refreshStatus(force: false)
        }

        func status() -> StatusPayload? {
            if let cachedStatus { return cachedStatus }
            guard let data = UserDefaults.standard.data(forKey: statusKey),
                  let decoded = try? JSONDecoder().decode(StatusPayload.self, from: data) else { return nil }
            cachedStatus = decoded
            return decoded
        }

        @discardableResult
        func refreshStatus(force: Bool) async -> StatusRefreshResult {
            guard let url = TrackingAPI.url(path: "status") else {
                return StatusRefreshResult(
                    payload: status(),
                    apiKeyState: TrackingAPI.hasConfiguredKey ? .valid : .missing,
                    fetchedLive: false)
            }
            var req = TrackingAPI.authenticatedRequest(url: url, timeout: 12)
            if !force, let etag = UserDefaults.standard.string(forKey: statusKey + ".etag") {
                req.setValue(etag, forHTTPHeaderField: "If-None-Match")
            }
            guard let (data, resp) = try? await URLSession.shared.data(for: req),
                  let http = resp as? HTTPURLResponse else {
                return StatusRefreshResult(
                    payload: status(),
                    apiKeyState: TrackingAPI.hasConfiguredKey ? .valid : .missing,
                    fetchedLive: false)
            }
            if http.statusCode == 401 {
                return StatusRefreshResult(
                    payload: status(),
                    apiKeyState: TrackingAPI.hasConfiguredKey ? .invalid : .missing,
                    fetchedLive: true)
            }
            if http.statusCode == 304 {
                return StatusRefreshResult(
                    payload: status(),
                    apiKeyState: .valid,
                    fetchedLive: true)
            }
            guard http.statusCode == 200,
                  let payload = try? JSONDecoder().decode(StatusPayload.self, from: data) else {
                return StatusRefreshResult(
                    payload: status(),
                    apiKeyState: TrackingAPI.apiKeyState(for: http),
                    fetchedLive: false)
            }
            cachedStatus = payload
            UserDefaults.standard.set(data, forKey: statusKey)
            if let etag = http.value(forHTTPHeaderField: "ETag") {
                UserDefaults.standard.set(etag, forKey: statusKey + ".etag")
            }
            return StatusRefreshResult(payload: payload, apiKeyState: .valid, fetchedLive: true)
        }

        func loadCoverageLayer(_ layerId: String) async {
            let key = coverageLayerPrefix + layerId
            let etagKey = key + ".etag"
            guard let url = TrackingAPI.url(path: "coverage/\(layerId)") else { return }
            var req = TrackingAPI.authenticatedRequest(url: url, timeout: 12)
            if let etag = UserDefaults.standard.string(forKey: etagKey) {
                req.setValue(etag, forHTTPHeaderField: "If-None-Match")
            }
            guard let (data, resp) = try? await URLSession.shared.data(for: req),
                  let http = resp as? HTTPURLResponse else { return }
            if http.statusCode == 304 {
                if let cached = coverageLayer(layerId),
                   cached.catalogVersion == coverageIndex()?.catalogVersion {
                    cachedLayers[layerId] = cached
                }
                return
            }
            guard http.statusCode == 200,
                  let payload = try? JSONDecoder().decode(CoverageLayerPayload.self, from: data) else { return }
            cachedLayers[layerId] = payload
            UserDefaults.standard.set(data, forKey: key)
            if let etag = http.value(forHTTPHeaderField: "ETag") {
                UserDefaults.standard.set(etag, forKey: etagKey)
            }
        }

        private func invalidateCoverageLayers() {
            cachedLayers = [:]
            for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix(coverageLayerPrefix) {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        private func refreshSources() async {
            guard let url = TrackingAPI.url(path: "sources") else { return }
            var req = TrackingAPI.authenticatedRequest(url: url)
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
            var req = TrackingAPI.authenticatedRequest(url: url)
            if let etag = UserDefaults.standard.string(forKey: coverageIndexKey + ".etag") {
                req.setValue(etag, forHTTPHeaderField: "If-None-Match")
            }
            guard let (data, resp) = try? await URLSession.shared.data(for: req),
                  let http = resp as? HTTPURLResponse else { return }
            if http.statusCode == 304 { _ = coverageIndex(); return }
            guard http.statusCode == 200,
                  let payload = try? JSONDecoder().decode(CoverageIndexPayload.self, from: data) else { return }
            if let previous = coverageIndex(), previous.catalogVersion != payload.catalogVersion {
                invalidateCoverageLayers()
            }
            cachedCoverageIndex = payload
            UserDefaults.standard.set(data, forKey: coverageIndexKey)
            if let etag = http.value(forHTTPHeaderField: "ETag") {
                UserDefaults.standard.set(etag, forKey: coverageIndexKey + ".etag")
            }
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

    static func status() async -> StatusPayload? {
        await Cache.shared.status()
    }

    static func refreshStatus(force: Bool = false) async -> StatusRefreshResult {
        await Cache.shared.refreshStatus(force: force)
    }

    static func refreshIfNeeded() async {
        await Cache.shared.refreshIfNeeded()
    }

    static func loadCoverageLayer(_ layerId: String) async {
        await Cache.shared.loadCoverageLayer(layerId)
    }
}

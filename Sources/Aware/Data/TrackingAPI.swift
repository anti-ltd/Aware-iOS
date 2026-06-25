import Foundation

enum TrackingAPI {
    enum ApiKeyState: Sendable {
        case missing
        case invalid
        case valid
    }

    static let origin = "https://anti.ltd"
    static let trackingBase = URL(string: "\(origin)/tracking/v1")!

    static func url(path: String, query: [URLQueryItem] = []) -> URL? {
        var c = URLComponents(url: trackingBase.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if !query.isEmpty { c?.queryItems = query }
        return c?.url
    }

    static var hasConfiguredKey: Bool {
        guard let key = apiKey, !key.isEmpty else { return false }
        if key.hasPrefix("PASTE_") { return false }
        if key.contains("your_key_here") { return false }
        return true
    }

    static func apiKeyState(for http: HTTPURLResponse?) -> ApiKeyState {
        guard hasConfiguredKey else { return .missing }
        guard let http else { return .valid }
        if http.statusCode == 401 { return .invalid }
        return .valid
    }

    static func authenticatedRequest(url: URL, timeout: TimeInterval? = nil) -> URLRequest {
        var req = URLRequest(url: url)
        if let timeout { req.timeoutInterval = timeout }
        applyAuth(to: &req)
        return req
    }

    static func applyAuth(to request: inout URLRequest) {
        guard let key = apiKey, !key.isEmpty else { return }
        request.setValue(key, forHTTPHeaderField: "X-API-Key")
    }

    private static var apiKey: String? {
        if let raw = Bundle.main.object(forInfoDictionaryKey: "AntiTrackingAPIKey") as? String {
            if let normalized = normalizeApiKey(raw) { return normalized }
        }
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["ANTI_TRACKING_API_KEY"],
           let normalized = normalizeApiKey(raw) {
            return normalized
        }
        #endif
        return nil
    }

    private static func normalizeApiKey(_ raw: String) -> String? {
        var key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if key.hasPrefix("$(") || key.isEmpty { return nil }
        if (key.hasPrefix("\"") && key.hasSuffix("\"")) || (key.hasPrefix("'") && key.hasSuffix("'")) {
            key = String(key.dropFirst().dropLast())
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return key.isEmpty ? nil : key
    }
}

import Foundation

enum TrackingAPI {
    static let origin = "https://anti.ltd"
    static let trackingBase = URL(string: "\(origin)/tracking/v1")!

    static func url(path: String, query: [URLQueryItem] = []) -> URL? {
        var c = URLComponents(url: trackingBase.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if !query.isEmpty { c?.queryItems = query }
        return c?.url
    }
}

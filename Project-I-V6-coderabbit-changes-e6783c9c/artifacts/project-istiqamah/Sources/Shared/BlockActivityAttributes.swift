import ActivityKit
import Foundation

struct BlockActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let blockName: String
        let startDate: Date
        let endDate: Date
        let timeLabel: String
        let pausedAt: Date?

        var isPaused: Bool { pausedAt != nil }
    }

    let blockID: UUID
    let dateKey: String

    var deepLink: URL? { deepLink() }

    func deepLink(action: String? = nil) -> URL? {
        var components = URLComponents()
        components.scheme = "project-istiqamah"
        components.host = "block"
        components.path = "/\(blockID.uuidString)"
        components.queryItems = [URLQueryItem(name: "date", value: dateKey)]
        if let action {
            components.queryItems?.append(URLQueryItem(name: "action", value: action))
        }
        return components.url
    }
}
